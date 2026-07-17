from feedback_service.security import SlidingWindowLimiter


def test_sliding_window_limiter_is_deterministic():
    current = [100.0]
    limiter = SlidingWindowLimiter(limit=2, window_seconds=60, clock=lambda: current[0])

    assert limiter.allow("author")
    assert limiter.allow("author")
    assert not limiter.allow("author")
    assert limiter.allow("someone-else")
    current[0] = 160.0
    assert limiter.allow("author")


def test_sliding_window_evicts_inactive_keys():
    current = [0.0]
    limiter = SlidingWindowLimiter(
        limit=2,
        window_seconds=10,
        clock=lambda: current[0],
    )
    assert limiter.allow("old-client")
    assert limiter.tracked_keys == 1

    current[0] = 11.0
    assert limiter.allow("new-client")
    assert limiter.tracked_keys == 1
