from flask import Blueprint, jsonify, request
from datetime import datetime
import uuid

community_bp = Blueprint('community', __name__)

_reports = []


@community_bp.route('/api/community-reports', methods=['GET'])
def get_reports():
    status_filter = request.args.get('status')
    severity_filter = request.args.get('severity')
    result = _reports
    if status_filter:
        result = [r for r in result if r['status'] == status_filter]
    if severity_filter:
        result = [r for r in result if r['severity'] == severity_filter]
    return jsonify(result)


@community_bp.route('/api/community-reports', methods=['POST'])
def submit_report():
    data = request.get_json()
    report = {
        'id': str(uuid.uuid4()),
        'title': data['title'],
        'description': data['description'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'severity': data.get('severity', 'medium'),
        'status': 'pending',
        'category': data.get('category', 'flooding'),
        'reported_at': datetime.utcnow().isoformat() + 'Z',
        'reported_by': data.get('reported_by'),
        'district_name': data.get('district_name'),
        'image_url': data.get('image_url'),
        'upvotes': 0,
    }
    _reports.append(report)
    return jsonify(report), 201


@community_bp.route('/api/community-reports/<string:report_id>/upvote', methods=['POST'])
def upvote_report(report_id: str):
    report = next((r for r in _reports if r['id'] == report_id), None)
    if not report:
        return jsonify({'error': 'Report not found'}), 404
    report['upvotes'] = report.get('upvotes', 0) + 1
    return jsonify(report)


@community_bp.route('/api/community-reports/<string:report_id>/verify', methods=['POST'])
def verify_report(report_id: str):
    report = next((r for r in _reports if r['id'] == report_id), None)
    if not report:
        return jsonify({'error': 'Report not found'}), 404
    report['status'] = 'verified'
    return jsonify(report)
