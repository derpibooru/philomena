use jemallocator::Jemalloc;

#[cfg(not(test))]
mod beam;
mod camo;
mod domains;
mod markdown;
mod markdown_diff;
#[cfg(test)]
mod tests;

#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;
