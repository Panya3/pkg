# curl ใช้ Schannel ไม่ได้ลิงก์ mbedtls ในบ้าน

curl เป็นสมาชิกตัวเดียวที่พึ่งไลบรารีอื่น และมันหา dependency ด้วย `find_package` แบบ module (ค้นจากไฟล์ในเครื่อง) ซึ่ง **ไม่รู้จัก** target ที่ hub `add_subdirectory` เข้าไปแล้ว การจะให้ curl ใช้ mbedtls/zlib/zstd ของ hub จึงต้องมี stage prefix สองจังหวะ (build+install ลง `stage/` ก่อน แล้ว configure curl ชี้ `CMAKE_PREFIX_PATH` ไปที่นั่น) ซึ่งการ configure รอบเดียวทำไม่ได้ รอบนี้จึงตั้ง `CURL_USE_SCHANNEL=ON` (TLS ของ Windows เอง) และปิด `CURL_ZLIB`/`CURL_ZSTD` เพื่อให้ curl configure/build ได้เดี่ยว ๆ

## Consequences

- mbedtls, zlib, zstd ยังเป็นสมาชิก hub ตามปกติ แต่ curl ไม่ได้ลิงก์มัน — และนี่เป็นเจตนา ไม่ใช่ของที่ลืมต่อ
- เมื่อต้องการ curl ที่ใช้ mbedtls จริง ต้องเพิ่มกลไก stage prefix ซึ่งเป็นการเปลี่ยนแปลงระดับโครง ไม่ใช่แค่เปิด flag
