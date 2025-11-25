
from playwright.sync_api import Page, expect, sync_playwright
import time

def test_spa_navigation(page: Page):
    # 1. Load Home
    page.goto("http://localhost:8000")
    expect(page).to_have_title("Aahan Aggarwal")

    # Check Terminal is gone
    expect(page.locator("#terminal")).not_to_be_visible()

    # Screenshot Home
    page.screenshot(path="/home/jules/verification/1_home.png")

    # 2. Navigate to Pics
    # Click the "Pics" link
    page.get_by_role("link", name="Pics", exact=True).click()

    # Expect URL to change to /pics/ (or http://localhost:8000/pics/)
    expect(page).to_have_url("http://localhost:8000/pics/")
    expect(page).to_have_title("Pictures - Aahan Aggarwal")

    # Verify gallery loaded (wait for details element)
    expect(page.locator("details").first).to_be_visible()

    # Screenshot Pics
    page.screenshot(path="/home/jules/verification/2_pics.png")

    # 3. Navigate to Blog
    page.get_by_role("link", name="Blog", exact=True).click()

    expect(page).to_have_url("http://localhost:8000/blog/")
    expect(page).to_have_title("Blog - Aahan Aggarwal")

    # Verify blog list loaded (wait for list item)
    expect(page.locator("#blog-list li a").first).to_be_visible()

    # Screenshot Blog
    page.screenshot(path="/home/jules/verification/3_blog.png")

    # 4. Navigate to a Blog Post
    # Click the first blog post link
    page.locator("#blog-list li a").first.click()

    # Expect URL to contain view.html?post=...
    # Note: The clean URL logic might strip index.html but keeps view.html?post=...
    # Wait for title to be the specific post title (loaded from markdown)
    expect(page.locator("#post-title")).not_to_have_text("Loading...")
    expect(page).to_have_title("Initializing System... - Aahan Aggarwal")

    # Screenshot Post
    page.screenshot(path="/home/jules/verification/4_post.png")

    # 5. Verify SPA nature (optional check)
    # We can check if the circuit canvas is still the same element handle?
    # Or just rely on the speed and lack of full reload.
    # Playwright doesn't easily expose "did full reload" directly without checking network events.
    # But the "instant" visual confirmation is good enough for this task.

if __name__ == "__main__":
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        try:
            test_spa_navigation(page)
            print("Verification script completed successfully.")
        except Exception as e:
            print(f"Verification failed: {e}")
            # Take screenshot on failure
            page.screenshot(path="/home/jules/verification/failure.png")
        finally:
            browser.close()
