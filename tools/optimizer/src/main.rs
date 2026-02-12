use anyhow::{Context, Result};

use lightningcss::stylesheet::{ParserOptions, PrinterOptions, StyleSheet};
use minify_html::{minify, Cfg};
use oxc_allocator::Allocator;
use oxc_codegen::{Codegen, CodegenOptions};
use oxc_minifier::{CompressOptions, Minifier, MinifierOptions};
use oxc_parser::Parser;
use oxc_span::SourceType;
use rayon::prelude::*;
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

const DIST_DIR: &str = "dist";
const IGNORE_DIRS: &[&str] = &[
    ".git",
    ".github",
    ".gemini",
    "target",
    "tools",
    "node_modules",
    "dist",
];

fn main() -> Result<()> {
    let start = std::time::Instant::now();
    println!("Starting optimization build...");

    if Path::new(DIST_DIR).exists() {
        fs::remove_dir_all(DIST_DIR).context("Failed to remove existing dist directory")?;
    }
    fs::create_dir_all(DIST_DIR).context("Failed to create dist directory")?;

    let files: Vec<PathBuf> = WalkDir::new(".")
        .follow_links(true)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| {
            let path = e.path();
            if !path.is_file() {
                return false;
            }

            for ignore in IGNORE_DIRS {
                if path.components().any(|c| c.as_os_str() == *ignore) {
                    return false;
                }
            }
            if let Some(file_name) = path.file_name() {
                if file_name.to_string_lossy().starts_with('.') {
                    if file_name.to_string_lossy() == ".nojekyll" {
                        return true;
                    }
                    return false;
                }
            }

            true
        })
        .map(|e| e.path().to_owned())
        .collect();

    println!("Found {} files to process", files.len());

    files.par_iter().try_for_each(|path| -> Result<()> {
        process_file(path)?;
        Ok(())
    })?;

    println!("Build completed in {:.2?}", start.elapsed());
    Ok(())
}

fn process_file(path: &Path) -> Result<()> {
    let relative_path = path.strip_prefix(".")?;
    let dest_path = Path::new(DIST_DIR).join(relative_path);

    if let Some(parent) = dest_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let extension = path.extension().and_then(|s| s.to_str()).unwrap_or("");
    let file_name = path.file_name().and_then(|s| s.to_str()).unwrap_or("");

    if file_name.contains(".min.") {
        return copy_file(path, &dest_path);
    }

    match extension {
        "html" => minify_html_file(path, &dest_path),
        "css" => minify_css_file(path, &dest_path),
        "js" => minify_js_file(path, &dest_path),
        _ => copy_file(path, &dest_path),
    }
}

fn minify_html_file(src: &Path, dest: &Path) -> Result<()> {
    let content = fs::read(src)?;
    let cfg = Cfg {
        minify_js: true,
        minify_css: true,
        keep_comments: false,
        ..Cfg::default()
    };
    let minified = minify(&content, &cfg);
    fs::write(dest, minified)?;
    Ok(())
}

fn minify_css_file(src: &Path, dest: &Path) -> Result<()> {
    let content = fs::read_to_string(src)?;
    let stylesheet = StyleSheet::parse(&content, ParserOptions::default())
        .map_err(|e| anyhow::anyhow!("Failed to parse CSS {:?}: {}", src, e))?;

    let options = PrinterOptions {
        minify: true,
        ..PrinterOptions::default()
    };
    let minified = stylesheet.to_css(options)?;
    fs::write(dest, minified.code)?;
    Ok(())
}

fn minify_js_file(src: &Path, dest: &Path) -> Result<()> {
    let source_text = fs::read_to_string(src)?;

    let allocator = Allocator::default();
    let source_type = SourceType::from_path(src)
        .unwrap_or(SourceType::default())
        .with_module(true);

    let parser = Parser::new(&allocator, &source_text, source_type);
    let ret = parser.parse();

    if !ret.errors.is_empty() {
        eprintln!(
            "Warning: Failed to parse JS {:?}, copying instead. Errors: {:?}",
            src, ret.errors
        );
        fs::copy(src, dest)?;
        return Ok(());
    }

    let mut program = ret.program;

    let minifier_options = MinifierOptions {
        mangle: true,
        compress: CompressOptions {
            drop_console: false,
            ..CompressOptions::default()
        },
    };
    Minifier::new(minifier_options).build(&allocator, &mut program);

    let codegen_options = CodegenOptions {
        minify: true,
        ..CodegenOptions::default()
    };
    let minified = Codegen::new().with_options(codegen_options).build(&program);

    fs::write(dest, minified.source_text)?;
    Ok(())
}

fn copy_file(src: &Path, dest: &Path) -> Result<()> {
    fs::copy(src, dest)?;
    Ok(())
}
