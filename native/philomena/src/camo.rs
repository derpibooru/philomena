use ring::hmac;
use std::env;
use url::Url;

fn trusted_host(mut url: Url) -> Option<String> {
    url.set_port(Some(443)).ok()?;
    url.set_scheme("https").ok()?;

    Some(url.to_string())
}

fn untrusted_host(url: Url, camo_host: String, camo_key: String) -> Option<String> {
    let camo_url = format!("https://{}", camo_host);
    let key = hmac::Key::new(hmac::HMAC_SHA1_FOR_LEGACY_USE_ONLY, camo_key.as_ref());
    let tag = hmac::sign(&key, url.to_string().as_bytes());
    let encoded = base16::encode_lower(tag.as_ref());

    let mut camo_uri = Url::parse(&camo_url).ok()?;
    camo_uri.set_path(&encoded);
    camo_uri.set_port(Some(443)).ok()?;
    camo_uri.set_scheme("https").ok()?;
    camo_uri
        .query_pairs_mut()
        .clear()
        .append_pair("url", &url.to_string());

    Some(camo_uri.to_string())
}

pub fn image_url(uri: String) -> Option<String> {
    let cdn_host = env::var("CDN_HOST").ok()?;
    let camo_host = env::var("CAMO_HOST").ok()?;
    let camo_key = env::var("CAMO_KEY").ok()?;

    if camo_key.is_empty() {
        return Some(uri);
    }

    let url = Url::parse(&uri).ok()?;

    match url.host_str() {
        Some(hostname) if hostname == cdn_host || hostname == camo_host => trusted_host(url),
        Some(_) => untrusted_host(url, camo_host, camo_key),
        None => Some(String::from("")),
    }
}
