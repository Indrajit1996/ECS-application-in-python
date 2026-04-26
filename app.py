from flask import Flask, jsonify, request
import os
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Health check endpoint for ECS
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for ALB/ECS health checks"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'flask-ecs-app'
    }), 200

# Root endpoint
@app.route('/', methods=['GET'])
def home():
    """Root endpoint"""
    logger.info("Root endpoint accessed")
    return jsonify({
        'message': 'Welcome to Flask ECS Application',
        'version': '1.0.0',
        'environment': os.getenv('ENVIRONMENT', 'development'),
        'timestamp': datetime.utcnow().isoformat()
    }), 200

# Sample API endpoint
@app.route('/api/data', methods=['GET'])
def get_data():
    """Sample data endpoint"""
    logger.info("Data endpoint accessed")
    return jsonify({
        'data': [
            {'id': 1, 'name': 'Item 1', 'value': 100},
            {'id': 2, 'name': 'Item 2', 'value': 200},
            {'id': 3, 'name': 'Item 3', 'value': 300}
        ],
        'count': 3,
        'timestamp': datetime.utcnow().isoformat()
    }), 200

# POST endpoint example
@app.route('/api/data', methods=['POST'])
def create_data():
    """Create data endpoint"""
    data = request.get_json()
    logger.info(f"Data creation requested: {data}")
    return jsonify({
        'message': 'Data created successfully',
        'received_data': data,
        'timestamp': datetime.utcnow().isoformat()
    }), 201

# Error handler
@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'error': 'Not found',
        'message': 'The requested resource was not found',
        'timestamp': datetime.utcnow().isoformat()
    }), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'error': 'Internal server error',
        'message': 'An internal error occurred',
        'timestamp': datetime.utcnow().isoformat()
    }), 500

if __name__ == '__main__':
    # This is for development only
    # In production, we'll use Uvicorn
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
