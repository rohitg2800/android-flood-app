# backend/twilio_sms.py  v1.0 — Step 3.5
# POST /api/sms-alert — sends SMS via Twilio when severity = CRITICAL.
# Called by Flutter when FCM push fails (offline device scenario).
# All credentials come from environment variables ONLY — never hardcoded.

import os
import logging
from typing import Optional
from fastapi import HTTPException
from pydantic import BaseModel

logger = logging.getLogger(__name__)

_CRITICAL_LEVELS = {'CRITICAL', 'SEVERE'}


class SmsAlertRequest(BaseModel):
    phone_number: str          # E.164 format: +91XXXXXXXXXX
    city:         str
    station_id:   str
    risk_level:   str
    current_level: float
    danger_level:  float


class TwilioSmsService:
    def __init__(self):
        self.account_sid  = os.environ.get('TWILIO_ACCOUNT_SID', '')
        self.auth_token   = os.environ.get('TWILIO_AUTH_TOKEN', '')
        self.from_number  = os.environ.get('TWILIO_FROM_NUMBER', '')
        self._client: Optional[object] = None

    def _get_client(self):
        if self._client is None:
            try:
                from twilio.rest import Client  # type: ignore
                self._client = Client(self.account_sid, self.auth_token)
            except ImportError:
                raise HTTPException(
                    status_code=503,
                    detail='Twilio SDK not installed on this server',
                )
        return self._client

    def send_alert(self, req: SmsAlertRequest) -> dict:
        if req.risk_level.upper() not in _CRITICAL_LEVELS:
            return {'sent': False, 'reason': 'risk_level below threshold'}

        if not all([self.account_sid, self.auth_token, self.from_number]):
            logger.warning('[SMS] Twilio env vars not configured — skipping')
            return {'sent': False, 'reason': 'twilio not configured'}

        body = (
            f'\U0001f6a8 OpsFlood ALERT: {req.city}\n'
            f'Risk: {req.risk_level.upper()}\n'
            f'Level: {req.current_level:.2f}m '
            f'(danger: {req.danger_level:.2f}m)\n'
            f'Stay safe. Check app for details.'
        )

        try:
            client = self._get_client()
            message = client.messages.create(
                body=body,
                from_=self.from_number,
                to=req.phone_number,
            )
            logger.info(f'[SMS] sent sid={message.sid} to={req.phone_number}')
            return {'sent': True, 'sid': message.sid}
        except Exception as e:
            logger.error(f'[SMS] send failed: {e}')
            raise HTTPException(status_code=502, detail=f'SMS send failed: {e}')


# Singleton
_svc = TwilioSmsService()


async def sms_alert_endpoint(req: SmsAlertRequest) -> dict:
    """
    Mount in FastAPI:
        from twilio_sms import sms_alert_endpoint, SmsAlertRequest
        app.post('/api/sms-alert')(sms_alert_endpoint)
    """
    return _svc.send_alert(req)
