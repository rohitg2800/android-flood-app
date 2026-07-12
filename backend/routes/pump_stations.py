from flask import Blueprint, jsonify, request
from datetime import datetime
import uuid

pump_stations_bp = Blueprint('pump_stations', __name__)

# In-memory store — replace with DB in production
_stations = [
    {
        'id': '1',
        'name': 'Gandhi Setu Pump Station',
        'location': 'Gandhi Setu, Patna',
        'latitude': 25.6093,
        'longitude': 85.1376,
        'status': 'operational',
        'capacity_liters_per_second': 500.0,
        'current_flow_rate': 320.5,
        'district_name': 'Patna',
        'last_inspected_at': '2026-06-28T10:00:00Z',
        'notes': 'All systems nominal',
    },
    {
        'id': '2',
        'name': 'Danapur Flood Control Station',
        'location': 'Danapur, Patna',
        'latitude': 25.6227,
        'longitude': 85.0453,
        'status': 'faulty',
        'capacity_liters_per_second': 350.0,
        'current_flow_rate': 0.0,
        'district_name': 'Patna',
        'last_inspected_at': '2026-06-20T08:30:00Z',
        'notes': 'Motor bearing replacement pending',
    },
]


@pump_stations_bp.route('/api/pump-stations', methods=['GET'])
def get_pump_stations():
    return jsonify(_stations)


@pump_stations_bp.route('/api/pump-stations/<string:station_id>', methods=['GET'])
def get_pump_station(station_id: str):
    station = next((s for s in _stations if s['id'] == station_id), None)
    if not station:
        return jsonify({'error': 'Station not found'}), 404
    return jsonify(station)


@pump_stations_bp.route('/api/pump-stations', methods=['POST'])
def create_pump_station():
    data = request.get_json()
    station = {
        'id': str(uuid.uuid4()),
        'name': data['name'],
        'location': data['location'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'status': data.get('status', 'operational'),
        'capacity_liters_per_second': data['capacity_liters_per_second'],
        'current_flow_rate': data.get('current_flow_rate', 0.0),
        'district_name': data.get('district_name'),
        'last_inspected_at': datetime.utcnow().isoformat() + 'Z',
        'notes': data.get('notes'),
    }
    _stations.append(station)
    return jsonify(station), 201


@pump_stations_bp.route('/api/pump-stations/<string:station_id>', methods=['PATCH'])
def update_pump_station(station_id: str):
    station = next((s for s in _stations if s['id'] == station_id), None)
    if not station:
        return jsonify({'error': 'Station not found'}), 404
    data = request.get_json()
    station.update({k: v for k, v in data.items() if k != 'id'})
    return jsonify(station)
