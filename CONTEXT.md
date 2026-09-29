# pkg

ศูนย์รวมไลบรารี (lib hub) — repo เดียวที่ pin ซอร์สของไลบรารีภายนอกไว้ทั้งหมด
แล้วสร้างออกมาเป็นไฟล์ที่โปรเจกต์อื่นหยิบไปใช้ได้ โดยไม่ต้องไปตามหาไลบรารีเองที่ไหนอีก

## Language

**hub** (ศูนย์รวม lib):
repo นี้ในฐานะแหล่งเดียวที่เก็บและสร้างไลบรารีภายนอกทั้งหมด
_Avoid_: package manager, SDK, distribution

**vendor/**:
โฟลเดอร์ที่เก็บซอร์สไลบรารีภายนอกเป็น submodule ซึ่ง superproject เป็นคนกำหนดว่าอยู่ commit ไหน
_Avoid_: third_party, deps/, external/, subprojects/

**dependency group** (กลุ่ม dependency):
การแบ่งไลบรารีตามความพร้อมเข้า build ของ hub — กลุ่ม A เข้าได้ด้วย CMake ของตัวเอง, กลุ่ม B เข้าได้แค่บางส่วน, กลุ่ม C ไม่มี CMake ให้ใช้เลย
_Avoid_: tier, layer, level, priority

**member** (สมาชิก hub):
ไลบรารีภายนอกหนึ่งตัวที่ถูกรับเข้า build ของ hub แล้ว ไม่ว่าจะผลิตไฟล์จริงหรือเป็น header-only
_Avoid_: package, module, component, dependency

**staged artifact**:
ผลลัพธ์ของสมาชิกที่ถูกจัดวางไว้ใต้ `bin/` ตามชื่อสมาชิก แทนที่จะค้างอยู่ใน build tree
_Avoid_: output, dist, install tree

**include root**:
โฟลเดอร์ที่ต้องใส่เป็น include path เพื่อใช้ header ของสมาชิกหนึ่งตัว — ใน hub นี้คือ `bin/include/<member>/`
_Avoid_: include dir, header path, public headers

**overlay**:
header ที่ hub เป็นเจ้าของเอง ถูกวางก่อน header ของ vendor ใน include path เพื่อเสริมเนื้อหาให้สมาชิกหนึ่งตัวโดยไม่ต้องแก้ไฟล์ใน `vendor/`
_Avoid_: patch, patchset, workaround, shim

**patch set**:
ไฟล์ diff ที่ hub เก็บไว้เองและลงกับซอร์สของ vendor ตอน configure ใช้เมื่อ overlay แทนกันไม่ได้
_Avoid_: diff, mod, override, fork

**build environment**:
เครื่องที่รัน configure/build ของ hub จริง ๆ — hub นี้ถือว่า CI คือ build environment ไม่ใช่เครื่องนักพัฒนา
_Avoid_: local machine, devbox, workstation
