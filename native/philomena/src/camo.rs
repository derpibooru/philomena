use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use ring::hmac;
use std::env;
use url::Url;

fn trusted_host(mut url: Url) -> Option<String> {
    url.set_port(Some(443)).ok()?;
    url.set_scheme("https").ok()?;

    Some(url.to_string())
}

fn untrusted_host(url: Url, camo_host: &str, camo_key: &str) -> Option<String> {
    let camo_url = format!("https://{camo_host}");
    let key = hmac::Key::new(hmac::HMAC_SHA1_FOR_LEGACY_USE_ONLY, camo_key.as_ref());
    let tag = hmac::sign(&key, url.to_string().as_bytes());
    let encoded = URL_SAFE_NO_PAD.encode(tag.as_ref());
    let encoded_url = URL_SAFE_NO_PAD.encode(url.as_ref());
    let path = format!("{encoded}/{encoded_url}");

    let mut camo_uri = Url::parse(&camo_url).ok()?;
    camo_uri.set_path(&path);
    camo_uri.set_port(Some(443)).ok()?;
    camo_uri.set_scheme("https").ok()?;

    Some(camo_uri.to_string())
}

pub fn image_url(uri: &str) -> Option<String> {
    let cdn_host = env::var("CDN_HOST").ok()?;
    let camo_host = env::var("CAMO_HOST").unwrap_or_else(|_| "".into());
    let camo_key = env::var("CAMO_KEY").unwrap_or_else(|_| "".into());

    if camo_key.is_empty() {
        return Some(uri.into());
    }

    let url = Url::parse(uri).ok()?;

    match url.host_str() {
        Some(hostname) if hostname == cdn_host || hostname == camo_host => trusted_host(url),
        Some(_) => untrusted_host(url, &camo_host, &camo_key),
        None => Some("".into()),
    }
}

pub fn image_url_careful(uri: &str) -> String {
    image_url(uri).unwrap_or_else(|| "".into())
}
