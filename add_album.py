import os
import json
import sys
import cloudinary
import cloudinary.uploader
import cloudinary.api
from pathlib import Path

def load_credentials():
    creds_file = Path("cloudinary_credentials.json")
    if creds_file.exists():
        with open(creds_file, "r") as f:
            return json.load(f)
    return {}

creds = load_credentials()
if not creds:
    print("Error: cloudinary_credentials.json not found.")
    sys.exit(1)

cloudinary.config(
    cloud_name=creds["cloud_name"],
    api_key=creds["api_key"],
    api_secret=creds["api_secret"]
)

def add_album(folder_path):
    folder_path = Path(folder_path)
    if not folder_path.exists():
        print(f"Error: Folder '{folder_path}' does not exist.")
        return

    album_name = folder_path.name
    print(f"Processing album: {album_name}")

    index_file = Path("pics/index.json")
    with open(index_file, "r") as f:
        data = json.load(f)

    base_url = data.get("base_url", "")
    
    max_id = 0
    for album in data.get("albums", []):
        for img_path in album.get("images", []):
            try:
                filename = Path(img_path).stem
                img_id = int(filename)
                if img_id > max_id:
                    max_id = img_id
            except ValueError:
                continue
    
    next_id = max_id + 1
    print(f"Starting auto-renumbering from ID: {next_id}")

    existing_album = next((a for a in data["albums"] if a["name"] == album_name), None)
    if existing_album:
        print(f"Album '{album_name}' already exists. Adding new images to it.")
        album_data = existing_album
    else:
        album_data = {"name": album_name, "images": []}
        data["albums"].append(album_data)

    valid_exts = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".gif"}
    
    files = [f for f in folder_path.iterdir() if f.suffix.lower() in valid_exts]
    files.sort(key=lambda x: x.name)

    if not files:
        print("No images found in folder.")
        return

    for img_file in files:
        new_filename = f"{next_id}{img_file.suffix.lower()}"
        print(f"  Uploading {img_file.name} as {new_filename}...")
        
        public_id = f"{album_name}/{next_id}"
        
        try:
            response = cloudinary.uploader.upload(
                str(img_file),
                public_id=public_id,
                folder=album_name,
                overwrite=True,
                resource_type="auto"
            )
            
            secure_url = response["secure_url"]
            
            if secure_url.startswith(base_url):
                stored_path = secure_url[len(base_url):]
                if stored_path.startswith("/"):
                    stored_path = stored_path[1:]
            else:
                stored_path = secure_url
            
            if stored_path not in album_data["images"]:
                album_data["images"].append(stored_path)
                print(f"    -> Added: {stored_path}")
            else:
                print(f"    -> Already in index")
            
            next_id += 1
                
        except Exception as e:
            print(f"    Error uploading {img_file.name}: {e}")

    with open(index_file, "w") as f:
        json.dump(data, f, indent=4)
    
    print(f"\nSuccess! Album '{album_name}' updated in pics/index.json")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 add_album.py <path_to_folder>")
        print("Example: python3 add_album.py ./new_pics/athens-2025")
    else:
        add_album(sys.argv[1])
