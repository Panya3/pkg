# รับสมาชิก hub ด้วย `add_subdirectory(... EXCLUDE_FROM_ALL)`

hub รวบไลบรารีใน `vendor/` เข้า CMake graph เดียว โดยเรียก `add_subdirectory(... EXCLUDE_FROM_ALL)` พร้อมตั้ง option ของแต่ละตัวจากไฟล์ glue ใน `cmake/deps/` แทนที่จะรัน build system ของแต่ละไลบรารีแยกกันแล้วค่อยประกอบผลลัพธ์ เพราะซอร์สอยู่ในเครื่องแล้วในรูป submodule และเราต้องการ target จริงเพื่อ alias เป็น `pkg::<member>` ให้ผู้ใช้ปลายทางลิงก์ได้ตรง

## Considered Options

- **superbuild ด้วย `ExternalProject`** — แต่ละไลบรารีได้ build dir ของตัวเอง แก้ปัญหาเรื่อง option ปนกันได้ แต่ไม่มี target ให้ลิงก์ตรง ๆ และต้องมีกลไก install/stage มาประกอบ ซึ่งเกินความจำเป็นสำหรับไลบรารีที่ build ด้วย CMake อยู่แล้ว
- **`FetchContent`** — ซ้ำซ้อน เพราะของอยู่ใน `vendor/` แล้ว
- **แก้ CMakeLists ของ vendor ให้เรียกกันเอง** — ขัดกับนโยบาย `vendor/` อ่านเท่านั้น (ADR-0004)

## Consequences

ไลบรารีที่พึ่ง `find_package` เพื่อหาเพื่อนบ้าน (curl → zlib/mbedtls/zstd) จะ **ไม่** เห็น target ที่ถูก `add_subdirectory` เข้าไปแล้ว จึงต้องตัดสินใจแยกต่อไลบรารี (ดู ADR-0005)
