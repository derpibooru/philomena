require 'open3'
require 'base64'
require 'fileutils'
require 'securerandom'

$PERMITTED_COMMANDS = %w[convert ffmpeg ffprobe file gifsicle identify image-intensities jpegtran magick mediastat mediathumb optipng safe-rsvg-convert svgstat]

class Application
  def call(env)
    req = Rack::Request.new(env)

    if req.post?
      run(req.body.read)
    else
      [405, {}, []]
    end
  end

  private

  def run(input)
    # Container-side script. Can be more lax here.

    cwd = "/tmp/#{SecureRandom.uuid}"
    FileUtils.mkdir_p(cwd)
    FileUtils.cd(cwd)

    progname = nil
    args = []
    files = []

    # Parse input
    input.each_line.with_index do |line, index|
      line.chomp!

      if index == 0
        progname = Base64.strict_decode64(line)

        unless $PERMITTED_COMMANDS.include?(progname.chomp)
          return [400, {}, []]
        end

        next
      end

      if index == 1
        args = line.split(",").map { |a| Base64.strict_decode64(a) }
        next
      end

      name, contents = line.split(":")
      files << name
      File.write(name, Base64.strict_decode64(contents.to_s))
    end

    # Run command
    stdout, stderr, status = Open3.capture3(progname, *args)

    # Generate output
    output = []

    output.push status.exitstatus.to_s
    output.push "\n"

    output.push Base64.strict_encode64(stdout)
    output.push "\n"

    output.push Base64.strict_encode64(stderr)
    output.push "\n"

    files.each do |file|
      output.push Base64.strict_encode64(File.read(file))
      output.push "\n"
    end

    FileUtils.cd("/")
    FileUtils.rm_rf(cwd)

    [200, {}, output]
  end
end

run Application.new
