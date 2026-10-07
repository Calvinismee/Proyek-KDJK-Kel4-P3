mahasiswa = [
    {"nama": "Andhika", "nim": "M0403241055", "nilai": 88},
    {"nama": "Hamdi", "nim": "M0403241080", "nilai": 92},
    {"nama": "Dolisy", "nim": "M0403241081", "nilai": 85},
    {"nama": "Calvin", "nim": "M0403241082", "nilai": 90},
]
 
total = sum(m["nilai"] for m in mahasiswa)
print("Daftar nilai:")
for m in mahasiswa:
    print(f"- {m['nim']} {m['nama']}: {m['nilai']}")
print(f"Rata-rata kelompok: {total / len(mahasiswa):.2f}")