use http::Uri;
use regex::Regex;
use std::env;

pub fn get() -> Option<Vec<String>> {
    if let Ok(domains) = env::var("SITE_DOMAINS") {
        return Some(
            domains
                .split(',')
                .map(|s| s.to_string())
                .collect::<Vec<String>>(),
        );
    }

    None
}

pub fn relativize(domains: &[String], url: &str) -> Option<String> {
    let uri = url.parse::<Uri>().ok()?;

    if let Some(a) = uri.authority() {
        if domains.contains(&a.host().to_string()) {
            if let Ok(re) = Regex::new(&format!(r#"^http(s)?://({})"#, regex::escape(a.host()))) {
                return Some(re.replace(url, "").into());
            }
        }
    }

    Some(url.into())
}

pub fn relativize_careful(domains: &[String], url: &str) -> String {
    relativize(domains, url).unwrap_or_else(|| url.into())
}
