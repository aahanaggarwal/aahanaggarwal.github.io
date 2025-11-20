import os
import json
import re

POSTS_DIR = 'blog/posts'
OUTPUT_FILE = 'blog/posts.json'

def parse_frontmatter(content):
    meta = {}
    # Simple frontmatter parser (between --- and ---)
    match = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
    if match:
        frontmatter = match.group(1)
        for line in frontmatter.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                meta[key.strip()] = value.strip()
    return meta

def main():
    posts = []
    if not os.path.exists(POSTS_DIR):
        print(f"Directory {POSTS_DIR} not found.")
        return

    for filename in os.listdir(POSTS_DIR):
        if filename.endswith('.md'):
            filepath = os.path.join(POSTS_DIR, filename)
            with open(filepath, 'r') as f:
                content = f.read()
                meta = parse_frontmatter(content)
                
                # Fallback if date/title not in frontmatter
                if 'title' not in meta:
                    meta['title'] = filename.replace('.md', '').replace('-', ' ').title()
                if 'date' not in meta:
                    # Try to extract date from filename YYYY-MM-DD
                    date_match = re.match(r'^(\d{4}-\d{2}-\d{2})', filename)
                    if date_match:
                        meta['date'] = date_match.group(1)
                    else:
                        meta['date'] = '1970-01-01'

                posts.append({
                    'file': filename,
                    'title': meta.get('title'),
                    'date': meta.get('date'),
                    'tags': meta.get('tags', '')
                })

    # Sort by date descending
    posts.sort(key=lambda x: x['date'], reverse=True)

    with open(OUTPUT_FILE, 'w') as f:
        json.dump(posts, f, indent=2)
    
    print(f"Successfully updated {OUTPUT_FILE} with {len(posts)} posts.")

if __name__ == "__main__":
    main()
