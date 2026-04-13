"""
Profile routes: GET and PUT patient profile.
"""

from fastapi import APIRouter, HTTPException
from models.api_models import ProfileUpdate, ProfileOut
from db.sqlite_db import get_profile, update_profile

router = APIRouter(tags=["profile"])


@router.get("/profile", response_model=ProfileOut)
async def read_profile():
    p = get_profile()
    if not p:
        raise HTTPException(404, "Profile not found")
    return ProfileOut(**p)


@router.put("/profile", response_model=ProfileOut)
async def write_profile(body: ProfileUpdate):
    updates = body.model_dump(exclude_none=True)
    if not updates:
        p = get_profile()
        return ProfileOut(**p)
    p = update_profile(**updates)
    return ProfileOut(**p)
