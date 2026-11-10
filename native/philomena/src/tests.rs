use std::{assert_matches, collections::HashMap, sync::Arc};

use crate::{domains, markdown::*};

fn test_options() -> comrak::Options<'static> {
    let mut options = common_options();
    options.extension.image_url_rewriter = None;
    options.extension.link_url_rewriter = None;
    options.extension.replacements = Some(Default::default());
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
        "<div class=\"paragraph\"><a href=\"https://example.com/search?q=1%2C2%2C3\">https://example.com/search?q=1%2C2%2C3</a></div>\n",
    );
}

#[test]
fn underscore_autolink_interaction() {
    html(
        "https://example.com/x_",
        "<div class=\"paragraph\"><a href=\"https://example.com/x_\">https://example.com/x_</a></div>\n",
    )
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
fn greentext_and_embed_after_quote_closes_the_quote() {
    html_opts_i(
        "> quote\n>>1p\nreply",
        "<blockquote>\n<div class=\"paragraph\">quote</div>\n</blockquote>\n<div class=\"paragraph\"><div id=\"1\">p</div><br />\nreply</div>\n",
        |opts| {
            let mut replacements = HashMap::new();
            replacements.insert("1p".to_string(), "<div id=\"1\">p</div>".to_string());

            opts.extension.replacements = Some(replacements);
        },
    );

    html(
        "> quote\n>implying",
        "<blockquote>\n<div class=\"paragraph\">quote</div>\n</blockquote>\n<div class=\"paragraph\">&gt;implying</div>\n",
    );

    html(
        "> a\n>> b",
        "<blockquote>\n<div class=\"paragraph\">a</div>\n</blockquote>\n<div class=\"paragraph\">&gt;&gt; b</div>\n",
    );

    html(
        "> quote\n>\treply",
        "<blockquote>\n<div class=\"paragraph\">quote<br />\nreply</div>\n</blockquote>\n",
    );
}

#[test]
fn separate_quotes_on_line_end() {
    html(
        "> 1\n>\n> 2",
        "<blockquote>\n<div class=\"paragraph\">1</div>\n<div class=\"paragraph\">2</div>\n</blockquote>\n",
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
    let domains = Arc::new(vec!["example.com".into()].into_iter().collect());
    let f = Arc::new(move |url: &str| domains::relativize(&*domains, url));

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

#[test]
fn autolink_email_recursion() {
    comrak::markdown_to_html(&"a@b.co ".repeat(30_000), &test_options());
    assert_eq!(1, 1);
}

#[test]
fn autolink_backtracking_pathological() {
    let timeout = std::time::Duration::from_millis(100);
    let (tx, rx) = std::sync::mpsc::channel();
    let md = format!("http://a.b{}", ")".repeat(100_000));
    std::thread::spawn(move || {
        comrak::markdown_to_html(&md, &test_options());
        tx.send(()).unwrap();
    });

    assert_matches!(rx.recv_timeout(timeout), Ok(_));
}

fn diff(old: &str, new: &str, expected: &str) {
    let output = crate::markdown_diff::to_html(old, new);

    if output != expected {
        println!("Old:\n========================\n{old}\n========================");
        println!("New:\n========================\n{new}\n========================");
        println!("Expected:\n========================\n{expected}\n========================");
        println!("Output:\n========================\n{output}\n========================");
    }
    assert_eq!(output, expected);
}

#[test]
fn diff_unchanged_document_renders_as_plain_context() {
    diff(
        "Hello world\n\nSecond line",
        "Hello world\n\nSecond line",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">1</td><td class=\"diff__gutter\">1</td><td class=\"diff__text\">Hello world</td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">2</td><td class=\"diff__gutter\">2</td><td class=\"diff__text\"></td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">3</td><td class=\"diff__gutter\">3</td><td class=\"diff__text\">Second line</td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn diff_word_change_highlights_only_the_changed_word() {
    diff(
        "The quick brown fox",
        "The quick red fox",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row diff__row--del\"><td class=\"diff__gutter\">1</td><td class=\"diff__gutter\"></td><td class=\"diff__text\">The quick <del class=\"diff__hl\">brown</del> fox</td></tr>",
            "<tr class=\"diff__row diff__row--ins\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\">1</td><td class=\"diff__text\">The quick <ins class=\"diff__hl\">red</ins> fox</td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn diff_inserted_line_gets_its_own_row_without_highlights() {
    diff(
        "First line\nThird line",
        "First line\nSecond line\nThird line",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">1</td><td class=\"diff__gutter\">1</td><td class=\"diff__text\">First line</td></tr>",
            "<tr class=\"diff__row diff__row--ins\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\">2</td><td class=\"diff__text\">Second line</td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">2</td><td class=\"diff__gutter\">3</td><td class=\"diff__text\">Third line</td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn diff_collapses_unchanged_lines_after_the_context_window() {
    diff(
        "start old\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9",
        "start new\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row diff__row--del\"><td class=\"diff__gutter\">1</td><td class=\"diff__gutter\"></td><td class=\"diff__text\">start <del class=\"diff__hl\">old</del></td></tr>",
            "<tr class=\"diff__row diff__row--ins\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\">1</td><td class=\"diff__text\">start <ins class=\"diff__hl\">new</ins></td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">2</td><td class=\"diff__gutter\">2</td><td class=\"diff__text\">l2</td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">3</td><td class=\"diff__gutter\">3</td><td class=\"diff__text\">l3</td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">4</td><td class=\"diff__gutter\">4</td><td class=\"diff__text\">l4</td></tr>",
            "<tr class=\"diff__row diff__row--gap\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\"></td><td class=\"diff__text\">5 unchanged lines</td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn diff_collapses_unchanged_lines_before_the_context_window() {
    diff(
        "l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nend old",
        "l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nend new",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row diff__row--gap\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\"></td><td class=\"diff__text\">5 unchanged lines</td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">6</td><td class=\"diff__gutter\">6</td><td class=\"diff__text\">l6</td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">7</td><td class=\"diff__gutter\">7</td><td class=\"diff__text\">l7</td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">8</td><td class=\"diff__gutter\">8</td><td class=\"diff__text\">l8</td></tr>",
            "<tr class=\"diff__row diff__row--del\"><td class=\"diff__gutter\">9</td><td class=\"diff__gutter\"></td><td class=\"diff__text\">end <del class=\"diff__hl\">old</del></td></tr>",
            "<tr class=\"diff__row diff__row--ins\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\">9</td><td class=\"diff__text\">end <ins class=\"diff__hl\">new</ins></td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn diff_keeps_raw_user_html_escaped() {
    diff(
        "before <script> text",
        "after <script> text",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row diff__row--del\"><td class=\"diff__gutter\">1</td><td class=\"diff__gutter\"></td><td class=\"diff__text\"><del class=\"diff__hl\">before</del> &lt;script&gt; text</td></tr>",
            "<tr class=\"diff__row diff__row--ins\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\">1</td><td class=\"diff__text\"><ins class=\"diff__hl\">after</ins> &lt;script&gt; text</td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn diff_from_empty_shows_pure_insertions() {
    diff(
        "",
        "line one\nline two",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row diff__row--ins\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\">1</td><td class=\"diff__text\">line one</td></tr>",
            "<tr class=\"diff__row diff__row--ins\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\">2</td><td class=\"diff__text\">line two</td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn diff_to_empty_shows_pure_deletions() {
    diff(
        "only line",
        "",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row diff__row--del\"><td class=\"diff__gutter\">1</td><td class=\"diff__gutter\"></td><td class=\"diff__text\">only line</td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn diff_matches_lines_across_crlf_and_lf_revisions() {
    diff(
        "same one\r\nsame two",
        "same one\nsame two\nadded three",
        concat!(
            "<table class=\"diff\"><tbody>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">1</td><td class=\"diff__gutter\">1</td><td class=\"diff__text\">same one</td></tr>",
            "<tr class=\"diff__row\"><td class=\"diff__gutter\">2</td><td class=\"diff__gutter\">2</td><td class=\"diff__text\">same two</td></tr>",
            "<tr class=\"diff__row diff__row--ins\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\">3</td><td class=\"diff__text\">added three</td></tr>",
            "</tbody></table>",
        ),
    );
}

#[test]
fn nif_api() {
    assert_eq!(
        to_html("*Hello world*", Default::default()),
        "<div class=\"paragraph\"><em>Hello world</em></div>\n"
    );
    assert_eq!(
        to_html_unsafe("<b>Hello world</b>", Default::default()),
        "<div class=\"paragraph\"><b>Hello world</b></div>\n"
    );
}
