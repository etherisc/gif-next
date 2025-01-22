import secrets
import string

PASSWORD_CHARS = string.ascii_letters + string.digits + ".:*+-@=!_"


def generate_password(length: int = 12) -> str:
    """Return a reasonable password.

    The length of the password is an optional parameter.
    """
    return generate_password_for_chars(PASSWORD_CHARS, length)


def generate_password_for_chars(chars: str, length: int) -> str:
    """Return a reasonable password using the provided chars and length."""
    # Use 'secrets.choice()' to select characters securely
    return "".join(secrets.choice(chars) for _ in range(length))
