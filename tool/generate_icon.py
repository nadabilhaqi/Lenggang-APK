"""Membangkitkan ikon peluncur Android Lenggang dari logo (butuh Pillow).

Jalankan dari akar repo:  python tool/generate_icon.py

Sumber: assets/brand/logo.png (1080 × 1080, latar gelap bergradasi vertikal).
Keluaran:
- mipmap-*/ic_launcher.png            ikon lama (sudut membulat)
- mipmap-*/ic_launcher_foreground.png lapisan depan ikon adaptif (Android 8+)
- docs/ikon-lenggang.png              pratinjau 512 px
"""

from PIL import Image, ImageDraw

SRC = 'assets/brand/logo.png'
RES = 'android/app/src/main/res'
DENSITIES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}

# Ikon adaptif memotong lapisan depan 108 dp menjadi bentuk 72 dp dan hanya
# menjamin area tengah 66 dp. Gambar logo mengisi ±70 % lebar berkas, jadi
# logo diperkecil ke 76 % kanvas agar seluruh gambar berada di area aman.
FOREGROUND_SCALE = 0.76


def rounded(img: Image.Image, radius_ratio: float) -> Image.Image:
    size = img.width
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * radius_ratio), fill=255
    )
    out = img.convert('RGBA')
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def adaptive_foreground(logo: Image.Image) -> Image.Image:
    """Logo di tengah kanvas yang lebih besar; tepinya diisi dengan meneruskan
    gradasi latar logo supaya tidak terlihat sambungan."""
    n = logo.width
    canvas_size = round(n / FOREGROUND_SCALE)
    off = (canvas_size - n) // 2
    column = logo.crop((0, 0, 1, n))  # gradasi vertikal di tepi kiri
    canvas = Image.new('RGB', (canvas_size, canvas_size), column.getpixel((0, 0)))
    canvas.paste(column.resize((canvas_size, n)), (0, off))
    bottom = column.getpixel((0, n - 1))
    canvas.paste(bottom, (0, off + n, canvas_size, canvas_size))
    canvas.paste(logo, (off, off))
    return canvas


def main() -> None:
    logo = Image.open(SRC).convert('RGB')
    foreground = adaptive_foreground(logo)
    for name, k in DENSITIES.items():
        legacy = round(48 * k)
        path = f'{RES}/mipmap-{name}/ic_launcher.png'
        rounded(logo.resize((legacy, legacy), Image.LANCZOS), 0.22).save(path)
        fg = round(108 * k)
        fg_path = f'{RES}/mipmap-{name}/ic_launcher_foreground.png'
        foreground.resize((fg, fg), Image.LANCZOS).save(fg_path)
        print(path, legacy, '|', fg_path, fg)
    rounded(logo.resize((512, 512), Image.LANCZOS), 0.22).save('docs/ikon-lenggang.png')
    print('docs/ikon-lenggang.png 512')
    r, g, b = logo.getpixel((0, logo.height // 2))
    print(f'warna latar tengah: #{r:02X}{g:02X}{b:02X}')


if __name__ == '__main__':
    main()
