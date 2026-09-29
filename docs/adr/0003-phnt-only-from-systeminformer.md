# เอาแค่ `phnt` จาก SystemInformer

จากทั้งโปรเจกต์ SystemInformer เราใช้เฉพาะ `vendor/systeminformer/phnt` ซึ่งเป็นไลบรารี header-only และมี `CMakeLists.txt` ที่พึ่งตัวเองได้จริง (มีแค่ `project()` + `add_library(phnt INTERFACE)`) ส่วน `phlib` และ `kphlib` ต้องใช้ฟังก์ชัน `si_add_library` จากโครง CMake ของ SystemInformer ทั้งชุด ซึ่งลากเครื่องมือและสมมติฐานของโปรเจกต์นั้นเข้ามาทั้งหมด

## Consequences

- สมาชิก hub ได้ชื่อว่า `phnt` ไม่ใช่ `systeminformer` — ชื่อที่ถูกคือส่วนที่เราใช้จริง
- ถ้าอนาคตต้องการ `phlib` ต้องกลับมาทบทวนข้อนี้ ไม่ใช่ค่อย ๆ เพิ่ม `add_subdirectory` เข้าไปเงียบ ๆ
