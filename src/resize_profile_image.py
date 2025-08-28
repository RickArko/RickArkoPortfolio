from PIL import Image
import os

# Use current working directory - assumes you run from project root or src folder
def get_project_paths():
    cwd = os.getcwd()
    
    # Check if we're in the src directory or project root
    if cwd.endswith('src'):
        base_dir = cwd
    elif os.path.exists(os.path.join(cwd, 'src')):
        base_dir = os.path.join(cwd, 'src')
    else:
        # Fallback: assume we're in src
        base_dir = cwd
    
    profile_image_path = os.path.join(base_dir, "static", "images", "profile-image.png")
    icon_path = os.path.join(base_dir, "static", "favicon.ico")
    
    return profile_image_path, icon_path

# Get paths dynamically
profile_image_path, icon_path = get_project_paths()

def crop_image_for_profile(input_path: str, output_path: str = None):
    """Crop and resize image for profile picture"""
    if output_path is None:
        output_path = profile_image_path
    
    # Handle relative paths
    if not os.path.isabs(input_path):
        base_dir = os.path.dirname(profile_image_path)
        input_path = os.path.join(base_dir, input_path)
    
    img = Image.open(input_path)

    # Make it square by cropping to center (focus on face/upper body recommended)
    width, height = img.size
    min_dim = min(width, height)
    left = (width - min_dim) / 2
    top = (height - min_dim) / 4   # shift crop up to include more upper body/face
    right = (width + min_dim) / 2
    bottom = top + min_dim

    img_cropped = img.crop((left, top, right, bottom))

    # Resize to 300x300
    img_resized = img_cropped.resize((300, 300), Image.LANCZOS)

    # Save as high-quality PNG
    img_resized.save(output_path, "PNG", quality=95, optimize=True)

    print(f"Profile picture saved at {output_path}")


def create_multi_size_ico(jpg_path: str, ico_path: str = None):
    """Create ICO with multiple sizes"""
    if ico_path is None:
        _, ico_path = get_project_paths()
    
    # Handle relative paths
    if not os.path.isabs(jpg_path):
        base_dir = os.path.dirname(profile_image_path)
        jpg_path = os.path.join(base_dir, jpg_path)
    
    img = Image.open(jpg_path)
    
    # Common ICO sizes
    sizes = [(16, 16), (32, 32), (48, 48), (64, 64)]
    
    # Create list of resized images
    icon_sizes = []
    for size in sizes:
        resized = img.resize(size, Image.Resampling.LANCZOS)
        if resized.mode != 'RGBA':
            resized = resized.convert('RGBA')
        icon_sizes.append(resized)
    
    # Save all sizes in one ICO file
    icon_sizes[0].save(ico_path, format='ICO', sizes=sizes)
    print(f"Created multi-size ICO: {ico_path}")


if __name__ == "__main__":
    # Using relative paths
    image_path = os.path.join("static", "images", "rick-cartoon.jpg")
    input_path = os.path.join("static", "images", "rope-bridge-rick.jpeg")
    
    crop_image_for_profile(image_path)
    create_multi_size_ico(input_path)
