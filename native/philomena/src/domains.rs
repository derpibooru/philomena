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
