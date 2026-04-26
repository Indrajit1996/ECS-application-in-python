"""
ASGI entry point for running Flask with Uvicorn
"""
from asgiref.wsgi import WsgiToAsgi
from app import app

# Convert WSGI Flask app to ASGI
asgi_app = WsgiToAsgi(app)
