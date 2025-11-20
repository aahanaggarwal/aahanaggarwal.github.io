
from playwright.sync_api import Page, expect, sync_playwright
import time
import re

def test_spa_timer(page: Page):
    # 1. Load Home
    page.goto("http://localhost:8000")

    # Wait a bit for timer to start counting
    time.sleep(2)

    # Get timer text
    timer_home = page.locator("#hud-timer").inner_text()
    print(f"Home Timer: {timer_home}")

    # 2. Navigate to Pics
    page.get_by_role("link", name="Pics", exact=True).click()
    expect(page).to_have_url("http://localhost:8000/pics/")

    # Wait a bit
    time.sleep(2)

    # Get timer text
    timer_pics = page.locator("#hud-timer").inner_text()
    print(f"Pics Timer: {timer_pics}")

    # Parse seconds to compare
    # Format: SESSION: HH:MM:SS
    def parse_seconds(text):
        match = re.search(r"(\d{2}):(\d{2}):(\d{2})", text)
        if match:
            h, m, s = map(int, match.groups())
            return h * 3600 + m * 60 + s
        return -1

    sec_home = parse_seconds(timer_home)
    sec_pics = parse_seconds(timer_pics)

    print(f"Seconds Home: {sec_home}")
    print(f"Seconds Pics: {sec_pics}")

    if sec_pics > sec_home:
        print("SUCCESS: Timer continued incrementing.")
    else:
        print("FAILURE: Timer reset or stopped.")
        raise Exception("Timer failed to persist")

if __name__ == "__main__":
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        try:
            test_spa_timer(page)
        except Exception as e:
            print(f"Test failed: {e}")
        finally:
            browser.close()
