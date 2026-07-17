import json

from feedback_service.catalog import StudyPlannerCatalog


class FakeResponse:
    def __init__(self, payload: dict):
        self.payload = json.dumps(payload).encode()

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def read(self, _limit: int) -> bytes:
        return self.payload


def test_catalog_cache_is_bounded_and_response_is_typed(monkeypatch):
    payload = {
        "courses": [
            {
                "courseId": "598",
                "courseNumber": "INFM1234",
                "title": "Machine Learning",
                "periodLabel": "Sommer 2026",
                "ects": float("nan"),
                "schedule": ["not forwarded"],
            },
            {"courseId": 123, "courseNumber": "bad", "title": "bad"},
        ]
    }
    monkeypatch.setattr(
        "feedback_service.catalog.urllib.request.urlopen",
        lambda *_args, **_kwargs: FakeResponse(payload),
    )
    catalog = StudyPlannerCatalog("https://catalog.test", max_cache_entries=2)

    first = catalog.search("first", 20)
    catalog.search("second", 20)
    catalog.search("third", 20)

    assert catalog.cache_entries == 2
    assert first["courses"] == [
        {
            "courseId": "598",
            "courseNumber": "INFM1234",
            "title": "Machine Learning",
            "periodLabel": "Sommer 2026",
            "ects": None,
            "lecturer": None,
            "types": [],
        }
    ]
