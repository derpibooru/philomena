use std::collections::BTreeSet;
use std::env;

use http::Uri;
use regex::Regex;
use std::sync::LazyLock;

pub type DomainSet = BTreeSet<String>;

static DOMAINS: LazyLock<Option<DomainSet>> = LazyLock::new(|| {
    if let Ok(domains) = env::var("SITE_DOMAINS") {
        return Some(domains.split(',').map(|s| s.to_string()).collect());
    }

    None
});

pub fn get() -> &'static Option<DomainSet> {
    &DOMAINS
}

pub fn try_relativize(domains: &DomainSet, url: &str) -> Option<String> {
    let uri = url.parse::<Uri>().ok()?;

    if let Some(a) = uri.authority()
        && domains.contains(a.host())
        && let Ok(re) = Regex::new(&format!(r#"^http(s)?://({})"#, regex::escape(a.host())))
    {
        return Some(re.replace(url, "").into());
    }

    Some(url.into())
}

pub fn relativize(domains: &DomainSet, url: &str) -> String {
    try_relativize(domains, url).unwrap_or_else(|| url.into())
}
