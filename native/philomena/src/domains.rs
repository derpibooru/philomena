use std::collections::BTreeSet;
use std::env;

use http::Uri;
use once_cell::sync::Lazy;
use regex::Regex;

pub type DomainSet = BTreeSet<String>;

static DOMAINS: Lazy<Option<DomainSet>> = Lazy::new(|| {
    if let Ok(domains) = env::var("SITE_DOMAINS") {
        return Some(domains.split(',').map(|s| s.to_string()).collect());
    }

    None
});

pub fn get() -> &'static Option<DomainSet> {
    &DOMAINS
}

pub fn relativize(domains: &DomainSet, url: &str) -> Option<String> {
    let uri = url.parse::<Uri>().ok()?;

    if let Some(a) = uri.authority() {
        if domains.contains(a.host()) {
            if let Ok(re) = Regex::new(&format!(r#"^http(s)?://({})"#, regex::escape(a.host()))) {
                return Some(re.replace(url, "").into());
            }
        }
    }

    Some(url.into())
}

pub fn relativize_careful(domains: &DomainSet, url: &str) -> String {
    relativize(domains, url).unwrap_or_else(|| url.into())
}
