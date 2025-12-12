At https://aahanaggarwal.github.io or https://aahan.dev

## Managing Content

### Adding a New Photo Album
**Prerequisite**: Ensure you have `cloudinary_credentials.json` in the root directory with your Cloudinary API keys.

1. Create a new folder (e.g., `paris-2024`) and place your image files (`.jpg`, `.png`, etc.) inside it. You can place this folder anywhere, but keeping it in `pics/` is a good convention.
2. Run the automation script:
   ```bash
   python3 add_album.py path/to/your-folder
   ```
   *Example: `python3 add_album.py pics/paris-2024`*

   This script will automatically:
   - Upload the images to Cloudinary.
   - Update `pics/index.json` with the new album name and image URLs.

### Adding a New Blog Entry
1. Create a new markdown file in `blog/posts/` (e.g., `blog/posts/my-new-post.md`).
2. Add the required frontmatter at the top of the file:
   ```markdown
   ---
   title: Your Post Title
   date: YYYY-MM-DD
   tags: tag1, tag2
   ---
   ```
3. Write your blog post content below the frontmatter.
4. Run the update script to regenerate the blog index:
   ```bash
   python3 update_blog.py
   ```
   This generates `blog/posts.json`, which the site uses to display the list of blog posts.
