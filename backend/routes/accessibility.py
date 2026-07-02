from flask import Blueprint, jsonify, request

accessibility_bp = Blueprint('accessibility', __name__)

# Per-user settings store — replace with persistent DB in production
_user_settings: dict = {}

_defaults = {
    'high_contrast': False,
    'large_text': False,
    'screen_reader_mode': False,
    'haptic_feedback': True,
    'text_to_speech_alerts': True,
    'custom_vibration_patterns': True,
    'reduce_motion': False,
    'text_scale_factor': 1.0,
}


@accessibility_bp.route('/api/accessibility/<string:user_id>', methods=['GET'])
def get_settings(user_id: str):
    settings = _user_settings.get(user_id, _defaults.copy())
    return jsonify(settings)


@accessibility_bp.route('/api/accessibility/<string:user_id>', methods=['PUT'])
def update_settings(user_id: str):
    data = request.get_json()
    existing = _user_settings.get(user_id, _defaults.copy())
    existing.update({k: v for k, v in data.items() if k in _defaults})
    _user_settings[user_id] = existing
    return jsonify(existing)
