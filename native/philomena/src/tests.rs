use std::{collections::HashMap, sync::Arc};

use crate::{domains, markdown::*};

fn test_options() -> comrak::Options {
    let mut options = common_options();
    options.extension.image_url_rewriter = None;
    options.extension.link_url_rewriter = None;
    options
}

fn html(input: &str, expected: &str) {
    html_opts_w(input, expected, &test_options());
}

fn html_opts_i<F>(input: &str, expected: &str, opts: F)
where
    F: Fn(&mut comrak::Options),
{
    let mut options = test_options();
    opts(&mut options);

    html_opts_w(input, expected, &options);
}

fn html_opts_w(input: &str, expected: &str, options: &comrak::Options) {
    let output = comrak::markdown_to_html(input, options);

    if output != expected {
        println!("Input:");
        println!("========================");
        println!("{}", input);
        println!("========================");
        println!("Expected:");
        println!("========================");
        println!("{}", expected);
        println!("========================");
        println!("Output:");
        println!("========================");
        println!("{}", output);
        println!("========================");
    }
    assert_eq!(output, expected);
}

#[test]
fn subscript() {
    html("H~2~O\n", "<div class=\"paragraph\">H<sub>2</sub>O</div>\n");
}

#[test]
fn subscript_autolink_interaction() {
    html(
        "https://example.com/search?q=1%2C2%2C3",
        "<div class=\"paragraph\"><a href=\"https://example.com/search?q=1%2C2%2C3\">https://example.com/search?q=1%2C2%2C3</a></div>\n"
    );
}

#[test]
fn spoiler() {
    html(
        "The ||dog dies at the end of Marley and Me||.\n",
        "<div class=\"paragraph\">The <span class=\"spoiler\">dog dies at the end of Marley and Me</span>.</div>\n",
    );
}

#[test]
fn spoiler_in_table() {
    html(
        "Text | Result\n--- | ---\n`||some clever text||` | ||some clever text||\n",
        concat!(
            "<table>\n",
            "<thead>\n",
            "<tr>\n",
            "<th>Text</th>\n",
            "<th>Result</th>\n",
            "</tr>\n",
            "</thead>\n",
            "<tbody>\n",
            "<tr>\n",
            "<td><code>||some clever text||</code></td>\n",
            "<td><span class=\"spoiler\">some clever text</span></td>\n",
            "</tr>\n",
            "</tbody>\n",
            "</table>\n"
        ),
    );
}

#[test]
fn spoiler_regressions() {
    html(
        "|should not be spoiler|\n||should be spoiler||\n|||should be spoiler surrounded by pipes|||",
        concat!(
            "<div class=\"paragraph\">|should not be spoiler|<br />\n",
            "<span class=\"spoiler\">should be spoiler</span><br />\n",
            "|<span class=\"spoiler\">should be spoiler surrounded by pipes</span>|</div>\n"
        ),
    );
}

#[test]
fn mismatched_spoilers() {
    html(
        "|||this is a spoiler with pipe in front||\n||this is not a spoiler|\n||this is a spoiler with pipe after|||",
        concat!(
            "<div class=\"paragraph\">|<span class=\"spoiler\">this is a spoiler with pipe in front</span><br />\n",
            "||this is not a spoiler|<br />\n",
            "<span class=\"spoiler\">this is a spoiler with pipe after</span>|</div>\n"
        ),
    );
}

#[test]
fn underline() {
    html(
        "__underlined__\n",
        "<div class=\"paragraph\"><u>underlined</u></div>\n",
    );
}

#[test]
fn no_setext_headings_in_philomena() {
    html(
        "text text\n---",
        "<div class=\"paragraph\">text text</div>\n<hr />\n",
    );
}

#[test]
fn greentext_preserved() {
    html(
        ">implying\n>>implying",
        "<div class=\"paragraph\">&gt;implying<br />\n&gt;&gt;implying</div>\n",
    );
}

#[test]
fn separate_quotes_on_line_end() {
    html(
        "> 1\n>\n> 2",
        "<blockquote>\n<div class=\"paragraph\">1</div>\n</blockquote>\n<div class=\"paragraph\">&gt;</div>\n<blockquote>\n<div class=\"paragraph\">2</div>\n</blockquote>\n"
    );
}

#[test]
fn unnest_quotes_on_line_end() {
    html(
        "> 1\n> > 2\n> 1",
        "<blockquote>\n<div class=\"paragraph\">1</div>\n<blockquote>\n<div class=\"paragraph\">2</div>\n</blockquote>\n<div class=\"paragraph\">1</div>\n</blockquote>\n",
    );
}

#[test]
fn unnest_quotes_on_line_end_commonmark() {
    html(
        "> 1\n> > 2\n> \n> 1",
        "<blockquote>\n<div class=\"paragraph\">1</div>\n<blockquote>\n<div class=\"paragraph\">2</div>\n</blockquote>\n<div class=\"paragraph\">1</div>\n</blockquote>\n",
    );
}

#[test]
fn philomena_images() {
    html(
        "![full](http://example.com/image.png)",
        "<div class=\"paragraph\"><span class=\"imgspoiler\"><img src=\"http://example.com/image.png\" alt=\"full\" /></span></div>\n",
    );
}

#[test]
fn no_empty_link() {
    html_opts_i(
        "[](https://example.com/evil.domain.for.seo.spam)",
        "<div class=\"paragraph\">[](https://example.com/evil.domain.for.seo.spam)</div>\n",
        |opts| opts.extension.autolink = false,
    );

    html_opts_i(
        "[    ](https://example.com/evil.domain.for.seo.spam)",
        "<div class=\"paragraph\">[    ](https://example.com/evil.domain.for.seo.spam)</div>\n",
        |opts| opts.extension.autolink = false,
    );
}

#[test]
fn empty_image_allowed() {
    html(
        "![   ](https://example.com/evil.domain.for.seo.spam)",
        "<div class=\"paragraph\"><span class=\"imgspoiler\"><img src=\"https://example.com/evil.domain.for.seo.spam\" alt=\"   \" /></span></div>\n",
    );
}

#[test]
fn image_inside_link_allowed() {
    html(
        "[![](https://example.com/image.png)](https://example.com/)",
        "<div class=\"paragraph\"><a href=\"https://example.com/\"><span class=\"imgspoiler\"><img src=\"https://example.com/image.png\" alt=\"\" /></span></a></div>\n",
    );
}

#[test]
fn image_mention() {
    html_opts_i(
        "hello world >>1234p >>1337",
        "<div class=\"paragraph\">hello world <div id=\"1234\">p</div> &gt;&gt;1337</div>\n",
        |opts| {
            let mut replacements = HashMap::new();
            replacements.insert("1234p".to_string(), "<div id=\"1234\">p</div>".to_string());

            opts.extension.replacements = Some(replacements);
        },
    );
}

#[test]
fn image_mention_line_start() {
    html_opts_i(
        ">>1234p",
        "<div class=\"paragraph\"><div id=\"1234\">p</div></div>\n",
        |opts| {
            let mut replacements = HashMap::new();
            replacements.insert("1234p".to_string(), "<div id=\"1234\">p</div>".to_string());

            opts.extension.replacements = Some(replacements);
        },
    );
}

#[test]
fn auto_relative_links() {
    let domains: Vec<String> = vec!["example.com".into()];
    let f = Arc::new(move |url: &str| domains::relativize_careful(&domains, url));

    html_opts_i(
        "[some link text](https://example.com/some/path)",
        "<div class=\"paragraph\"><a href=\"/some/path\">some link text</a></div>\n",
        |opts| {
            opts.extension.link_url_rewriter = Some(f.clone());
        },
    );

    html_opts_i(
        "https://example.com/some/path",
        "<div class=\"paragraph\"><a href=\"/some/path\">https://example.com/some/path</a></div>\n",
        |opts| {
            opts.extension.link_url_rewriter = Some(f.clone());
        },
    );

    html_opts_i(
        "[some link text](https://example.com/some/path?parameter=aaaaaa&other_parameter=bbbbbb#id12345)",
        "<div class=\"paragraph\"><a href=\"/some/path?parameter=aaaaaa&amp;other_parameter=bbbbbb#id12345\">some link text</a></div>\n",
        |opts| {
            opts.extension.link_url_rewriter = Some(f.clone());
        },
    );

    html_opts_i(
        "https://example.com/some/path?parameter=aaaaaa&other_parameter=bbbbbb#id12345",
        "<div class=\"paragraph\"><a href=\"/some/path?parameter=aaaaaa&amp;other_parameter=bbbbbb#id12345\">https://example.com/some/path?parameter=aaaaaa&amp;other_parameter=bbbbbb#id12345</a></div>\n",
        |opts| {
            opts.extension.link_url_rewriter = Some(f.clone());
        },
    );
}
