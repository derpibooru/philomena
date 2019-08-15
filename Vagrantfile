Vagrant.configure('2') do |config|
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true

  config.vm.box = 'debian/buster64'
  config.vm.provider 'virtualbox' do |v|
    v.cpus = 2
    v.memory = 1280
  end

  config.vm.define 'default' do |node|
    node.vm.hostname = 'philomena.lc'
    node.vm.network :private_network, ip: '192.168.64.79'
  end

  config.vm.synced_folder '.', '/vagrant', type: 'virtualbox'
  config.vm.provision 'shell', path: 'vagrant/install.bash'
end
