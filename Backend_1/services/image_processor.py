from agno.media import Image

def prepare_image(file_path: str) -> Image:
    """
    Prepares an image file to be sent to Gemini.
    """
    return Image(filepath=file_path)
