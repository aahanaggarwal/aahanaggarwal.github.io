import os
import json
from pathlib import Path

# --- Configuration ---
PICS_DIR = "pics"       # The main directory containing all image subfolders
JSON_FILE = "pics/index.json"  # The JSON file to read and update
# ---------------------

def rename_images():
    print("Starting image renaming process...")

    # 1. Load the JSON file
    try:
        with open(JSON_FILE, 'r') as f:
            # Data is now a list of objects
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: JSON file not found at {JSON_FILE}")
        return
    except json.JSONDecodeError:
        print(f"Error: Could not decode JSON from {JSON_FILE}")
        return

    print(f"Loaded {JSON_FILE}, found {len(data)} album entries.")

    # 2. Build a map of all existing image files for quick lookup
    print(f"Scanning {PICS_DIR} for all image files...")
    file_map = {}  # Maps 'filename.ext': Path('/full/path/to/file')
    try:
        for file_path in Path(PICS_DIR).rglob('*'):
            if file_path.is_file():
                file_map[file_path.name] = file_path
    except FileNotFoundError:
        print(f"Error: 'pics' directory not found at {PICS_DIR}")
        return
        
    print(f"Found {len(file_map)} files on disk in {PICS_DIR}.")

    # 3. Iterate, rename files, and prepare new JSON data
    # This counter is now global and increments across all albums
    global_image_counter = 1 
    
    files_renamed = 0
    files_missing = 0
    total_images_in_json = 0

    # Iterate over each album object in the list
    for album in data:
        if "images" not in album or not isinstance(album["images"], list):
            print(f"Skipping entry '{album.get('name', 'N/A')}' - no 'images' list found.")
            continue

        old_filenames = album["images"]
        new_filenames_for_this_album = []
        total_images_in_json += len(old_filenames)

        # Iterate over the image names in this specific album
        for old_name in old_filenames:
            if old_name not in file_map:
                print(f"Warning: File '{old_name}' (from album '{album.get('name')}') is in JSON but not found in '{PICS_DIR}'. Skipping.")
                files_missing += 1
                continue  # Skip this file

            old_path = file_map[old_name]
            # Use original extension (.jpg, .webp, .heic)
            extension = old_path.suffix  
            
            # Use the global counter for the new name
            new_name = f"{global_image_counter}{extension}"
            new_path = old_path.parent / new_name

            try:
                # Only rename if the name is actually different
                if old_path != new_path:
                    old_path.rename(new_path)
                    print(f"Renamed: {old_path.name} -> {new_name}")
                else:
                    print(f"Skipped (already named): {old_name}")
                
                files_renamed += 1
                # Add the new name to this album's new list
                new_filenames_for_this_album.append(new_name)
                
                # IMPORTANT: Increment the global counter
                global_image_counter += 1 

            except OSError as e:
                print(f"Error renaming {old_name} to {new_name}: {e}")
        
        # 4. Update this album's "images" list with the new names
        album["images"] = new_filenames_for_this_album

    # 5. Write the updated JSON (the entire list of objects) back to the file
    try:
        with open(JSON_FILE, 'w') as f:
            # Using 4 spaces for indentation, like your original file
            json.dump(data, f, indent=4)
    except IOError as e:
        print(f"Error writing updated JSON to {JSON_FILE}: {e}")
        return

    print("\n--- Process Complete ---")
    print(f"Total images listed in JSON: {total_images_in_json}")
    print(f"Files successfully renamed: {files_renamed}")
    print(f"Files in JSON but not found on disk: {files_missing}")
    print(f"Total files in new JSON: {files_renamed}")
    print(f"{JSON_FILE} has been updated. ✅")

# Run the main function
if __name__ == "__main__":
    rename_images()