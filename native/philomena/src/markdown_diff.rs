// GitHub-style "pretty" diffing of two Markdown documents.
//
// The Markdown source is diffed line-by-line and rendered as a unified diff
// table: each line becomes a row with old/new line-number gutters, changed
// rows are marked with `diff__row--del` / `diff__row--ins`, and runs of
// unchanged lines beyond the context window collapse into an
// "N unchanged lines" separator row. When a line is edited in place, the
// exact changed words inside it are additionally wrapped in
// `<del class="diff__hl">` / `<ins class="diff__hl">`.
//
// The source text is HTML-escaped as it is emitted, so untrusted input stays
// inert; the only live markup is the table structure and the diff wrappers.

use similar::{Algorithm, ChangeTag, InlineChange, TextDiff};
use std::fmt::Write;
use std::time::Duration;

/// Number of unchanged lines shown around each hunk.
const CONTEXT_LINES: usize = 3;

/// Render an HTML diff table comparing `old` to `new`.
pub fn to_html(old: &str, new: &str) -> String {
    let old = normalize(old);
    let new = normalize(new);

    let diff = TextDiff::configure()
        .algorithm(Algorithm::Patience)
        .timeout(Duration::from_millis(50))
        .diff_lines(old.as_str(), new.as_str());

    let mut rows = String::new();
    let groups = diff.grouped_ops(CONTEXT_LINES);

    if groups.is_empty() {
        // Identical revisions: show the whole document as plain context.
        for change in diff.iter_all_changes() {
            let mut content = String::new();
            escape_into(&mut content, trim_newline(change.value()));
            push_row(
                &mut rows,
                ChangeTag::Equal,
                change.old_index(),
                change.new_index(),
                &content,
            );
        }
    } else {
        let old_total = diff.ops().last().map_or(0, |op| op.old_range().end);
        let mut shown_to = 0;

        for group in &groups {
            let start = group.first().map_or(0, |op| op.old_range().start);
            push_gap(&mut rows, start - shown_to);

            for op in group {
                for change in diff.iter_inline_changes(op) {
                    let content = inline_content(&change);
                    push_row(
                        &mut rows,
                        change.tag(),
                        change.old_index(),
                        change.new_index(),
                        &content,
                    );
                }
            }

            shown_to = group.last().map_or(shown_to, |op| op.old_range().end);
        }

        push_gap(&mut rows, old_total - shown_to);
    }

    format!("<table class=\"diff\"><tbody>{rows}</tbody></table>")
}

/// Render one line's content, wrapping the emphasized (changed) pieces in
/// `<del>`/`<ins>` highlight tags and escaping everything else.
fn inline_content(change: &InlineChange<str>) -> String {
    let emphasis = match change.tag() {
        ChangeTag::Delete => Some("del"),
        ChangeTag::Insert => Some("ins"),
        ChangeTag::Equal => None,
    };

    let mut html = String::new();

    for (emphasized, piece) in change.iter_strings_lossy() {
        let piece = trim_newline(&piece);
        if piece.is_empty() {
            continue;
        }

        match emphasis {
            Some(tag) if emphasized => {
                let _ = write!(html, "<{tag} class=\"diff__hl\">");
                escape_into(&mut html, piece);
                let _ = write!(html, "</{tag}>");
            }
            _ => escape_into(&mut html, piece),
        }
    }

    html
}

/// Append one diff table row with both line-number gutters and the rendered
/// line content.
fn push_row(
    out: &mut String,
    tag: ChangeTag,
    old_index: Option<usize>,
    new_index: Option<usize>,
    content: &str,
) {
    let row_class = match tag {
        ChangeTag::Equal => "diff__row",
        ChangeTag::Delete => "diff__row diff__row--del",
        ChangeTag::Insert => "diff__row diff__row--ins",
    };

    out.push_str("<tr class=\"");
    out.push_str(row_class);
    out.push_str("\">");
    push_gutter(out, old_index);
    push_gutter(out, new_index);
    out.push_str("<td class=\"diff__text\">");
    out.push_str(content);
    out.push_str("</td></tr>");
}

/// Append a separator row for `count` collapsed unchanged lines.
fn push_gap(out: &mut String, count: usize) {
    if count == 0 {
        return;
    }

    let noun = if count == 1 { "line" } else { "lines" };
    let _ = write!(
        out,
        "<tr class=\"diff__row diff__row--gap\"><td class=\"diff__gutter\"></td><td class=\"diff__gutter\"></td><td class=\"diff__text\">{count} unchanged {noun}</td></tr>"
    );
}

/// Append a line-number gutter cell, empty when the line only exists on the
/// other side.
fn push_gutter(out: &mut String, index: Option<usize>) {
    match index {
        Some(i) => {
            let _ = write!(out, "<td class=\"diff__gutter\">{}</td>", i + 1);
        }
        None => out.push_str("<td class=\"diff__gutter\"></td>"),
    }
}

/// Normalize a document for line diffing: CRLF becomes LF, and a missing
/// final terminator is added. Line values are compared including their
/// terminator, so without this, equal lines from different sources (form
/// submissions use CRLF and may drop the last newline) fail to match.
fn normalize(text: &str) -> String {
    let mut text = text.replace("\r\n", "\n");

    if !text.is_empty() && !text.ends_with('\n') {
        text.push('\n');
    }

    text
}

/// Strip a trailing line terminator; diff line values include it, but each
/// line renders as its own table row.
fn trim_newline(text: &str) -> &str {
    let text = text.strip_suffix('\n').unwrap_or(text);
    text.strip_suffix('\r').unwrap_or(text)
}

/// Minimal HTML escape for text content and attribute values.
fn escape_into(out: &mut String, text: &str) {
    for ch in text.chars() {
        match ch {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            _ => out.push(ch),
        }
    }
}
