from iridescent_bg import generate_iridescent_background, add_text

# Uses my pypi package iridescent_bg
# Wide and talle for better readability
bg = generate_iridescent_background(width=1600, height=240, enhance_vibrancy=True)

# Adjust font size accordingly
final_logo = add_text(
    bg,
    text="looSTAAR",
    font_size=100,  # Bump up font size now that we have more height
    font_color=(255, 255, 255),
    position=(620, 70)  # manually tuned center
)

# Save to man/figures
final_logo.save("man/figures/logo.png", dpi=(600, 600))
