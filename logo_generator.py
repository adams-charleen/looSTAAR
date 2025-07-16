from iridescent_bg import generate_iridescent_background
from PIL import ImageDraw, ImageFont

# Generate iridescent background from Charleen Adams' iridescent_bg python package
bg = generate_iridescent_background(width=1080, height=1080, enhance_vibrancy=True)

# Prepare drawing context
draw = ImageDraw.Draw(bg)

# Load font (adjust path if necessary)
font_path = "/Library/Fonts/Arial Bold.ttf"
font_size = 160
font = ImageFont.truetype(font_path, font_size)

# Text to add
text = "looSTAAR"

# Measure text bounding box
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]

# Center the text
x = (bg.width - text_width) // 2
y = (bg.height - text_height) // 2

# Draw centered white text
draw.text((x, y), text, font=font, fill="white")

# Save to looSTAAR package directory
bg.save("/Users/charleenadams/R_packages/looSTAAR/man/figures/logo.png", dpi=(600, 600))
