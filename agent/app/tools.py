"""Mock travel tools. Deterministic data so the demo needs no third-party APIs."""
import hashlib

from langchain_core.tools import tool


def _seed(*parts: str) -> int:
    return int(hashlib.sha256("|".join(p.lower() for p in parts).encode()).hexdigest(), 16)


@tool
def search_flights(origin: str, destination: str, date: str) -> str:
    """Search flights between two cities on a date (YYYY-MM-DD or free text)."""
    s = _seed(origin, destination, date)
    out = []
    for i, airline in enumerate(["SkyJet", "AeroBlue", "TransAir"]):
        price = 120 + (s >> (i * 8)) % 380
        dep = f"{6 + (s >> (i * 5)) % 14:02d}:{(s >> (i * 3)) % 4 * 15:02d}"
        out.append(f"{airline} {origin}->{destination} {date} dep {dep} ${price}")
    return "\n".join(out)


@tool
def search_hotels(city: str, nights: int = 3) -> str:
    """Search hotels in a city for a number of nights."""
    s = _seed(city)
    names = ["Grand Central", "Riverside Inn", "Old Town Boutique"]
    return "\n".join(
        f"{n} {city}: ${60 + (s >> (i * 7)) % 200}/night, {nights} nights, rating {3.5 + ((s >> i) % 15) / 10:.1f}"
        for i, n in enumerate(names)
    )


@tool
def get_weather(city: str, month: str) -> str:
    """Typical weather for a city in a given month."""
    s = _seed(city, month)
    return f"{city} in {month}: avg high {12 + s % 20}C, avg low {4 + s % 12}C, {s % 10} rainy days"


TOOLS = [search_flights, search_hotels, get_weather]
