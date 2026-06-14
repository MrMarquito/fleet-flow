import requests
import time
import random

API_URL = "http://localhost:3000/api/telemetry"

assets = [
    {"id": "Truck-A1", "lat": 37.790, "lng": -122.400, "vx": 0.0001, "vy": 0.0001},
    {"id": "Drone-B2", "lat": 37.788, "lng": -122.405, "vx": -0.0002, "vy": 0.0001},
]

def simulate():
    print("Starting simulation...")
    while True:
        for asset in assets:
            # Update position
            asset["lat"] += asset["vx"] + (random.random() - 0.5) * 0.00005
            asset["lng"] += asset["vy"] + (random.random() - 0.5) * 0.00005
            
            payload = {
                "id": asset["id"],
                "lat": asset["lat"],
                "lng": asset["lng"]
            }
            
            try:
                response = requests.post(API_URL, json=payload)
                if response.status_code == 200:
                    status = response.json().get("status")
                    print(f"Sent {asset['id']}: ({asset['lat']:.5f}, {asset['lng']:.5f}) - Status: {status}")
                else:
                    print(f"Error sending {asset['id']}: {response.status_code}")
            except Exception as e:
                print(f"Connection error: {e}")
        
        time.sleep(2)

if __name__ == "__main__":
    simulate()
