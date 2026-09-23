# EcoAnalyze Backend API

FastAPI backend providing real-time and historical environmental data, dynamic scoring, alerts, and recommendations for the EcoAnalyze Flutter application.

## Directory Structure

```
eco_analyze_backend/
│
├── main.py                     # FastAPI application & endpoints
├── requirements.txt            # Dependencies (fastapi, uvicorn, pydantic)
├── run_server.bat              # One-click start script for Windows
├── README.md                   # Backend documentation
└── data/
    └── environmental_data.json # Persistent JSON data store
```

## Running the Server

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Start the API Server
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Or simply double-click `run_server.bat`.

### 3. Interactive Documentation
Once started, visit:
- **Swagger UI**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **ReDoc**: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)

## Key Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | API welcome info and health status |
| `GET` | `/api/dashboard?location=Chennai` | Complete payload formatted for Flutter dashboard |
| `GET` | `/api/data` | Get all environmental history records |
| `GET` | `/api/data/latest?location=Chennai` | Get the most recent environmental reading |
| `GET` | `/api/locations` | List of all monitored locations with scores |
| `POST` | `/api/data` | Post new sensor/weather data (auto-calculates score) |
| `DELETE`| `/api/data/{id}` | Delete a record by ID |
