# دليل تثبيت وتجهيز Docker Engine على Debian

مرجع عربي عملي ومفصل لتثبيت Docker Engine على Debian 13 (Trixie)، سواء كان Debian يعمل داخل WSL2 أو Virtual Machine أو مثبتًا مباشرة على الجهاز.

> هذا الدليل يثبت **Docker Engine داخل Debian**، وليس Docker Desktop على Windows.

---

## 1. الصورة العامة

في البيئة التي جهزناها تكون الطبقات بهذا الشكل:

```text
Windows
└── WSL2
    └── Debian 13 (Trixie)
        ├── Docker CLI
        ├── Docker Engine (dockerd)
        ├── containerd
        ├── Buildx
        └── Docker Compose
```

Docker CLI يستقبل الأوامر التي تكتبها، مثل `docker build` و`docker run`. ثم يتواصل مع Docker Engine عبر Docker socket. المحرك يدير الصور والحاويات والشبكات والـvolumes، ويستخدم `containerd` داخليًا لتشغيل الحاويات.

```text
Docker CLI → Docker socket → dockerd → containerd → container
```

---

## 2. هل تختلف الخطوات حسب مكان تشغيل Debian؟

خطوات تثبيت Docker داخل Debian متشابهة تقريبًا في الحالات التالية:

- Debian داخل WSL2.
- Debian داخل VirtualBox أو VMware.
- Debian مثبت مباشرة على الجهاز.
- Debian بواجهة رسومية GUI أو بدون واجهة.

الاختلاف الأساسي ليس في Docker، بل في إدارة الموارد والشبكة والملفات:

| البيئة | الموارد | الوصول للموقع من الجهاز المضيف | الملفات |
|---|---|---|---|
| WSL2 | عبر ملف `.wslconfig` في Windows | غالبًا عبر `localhost` | الأفضل العمل داخل `/home` وليس `/mnt/c` |
| VirtualBox NAT | من إعدادات الـVM | قد تحتاج Port Forwarding | داخل القرص الافتراضي للـVM |
| VirtualBox Bridged | من إعدادات الـVM | عبر IP خاص بالـVM | داخل القرص الافتراضي للـVM |
| Debian أصلي | موارد الجهاز مباشرة | عبر `localhost` | داخل نظام ملفات Debian |

وجود GUI لا يفيد Docker Engine بحد ذاته، بل يستهلك جزءًا إضافيًا من RAM والمعالج.

---

## 3. المتطلبات قبل التثبيت

تحقق من إصدار Debian:

```bash
cat /etc/os-release
```

ولطباعة الاسم الرمزي فقط:

```bash
. /etc/os-release && echo "$VERSION_CODENAME"
```

في Debian 13 يجب أن تكون النتيجة:

```text
trixie
```

تحقق من معمارية النظام:

```bash
dpkg --print-architecture
```

على أجهزة Intel وAMD الحديثة ذات 64 بت تكون النتيجة غالبًا:

```text
amd64
```

اسم `amd64` يشمل معالجات Intel وAMD التي تستخدم معمارية x86-64.

---

## 4. تثبيت الأدوات الأولية

حدّث فهرس الحزم:

```bash
sudo apt update
```

ثبّت شهادات HTTPS وأداة التنزيل `curl`:

```bash
sudo apt install ca-certificates curl
```

### لماذا نحتاجهما؟

- `ca-certificates`: يسمح للنظام بالتحقق من شهادات HTTPS والاتصال بالمستودع الرسمي بصورة آمنة.
- `curl`: ينزّل مفتاح التوقيع الرسمي الخاص بـDocker.

---

## 5. إنشاء مجلد مفاتيح APT

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

شرح الأمر:

- `sudo`: تشغيل بصلاحيات المسؤول لأن `/etc` محمي.
- `install`: ينشئ ملفات أو مجلدات مع تحديد الصلاحيات.
- `-d`: إنشاء مجلد.
- `-m 0755`: المالك يستطيع القراءة والكتابة والدخول، والآخرون يستطيعون القراءة والدخول.
- `/etc/apt/keyrings`: المكان المخصص لمفاتيح مستودعات APT.

عدم ظهور نتيجة بعد تنفيذ الأمر يعني عادةً أنه نجح.

---

## 6. تنزيل مفتاح Docker الرسمي

```bash
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
```

شرح الخيارات:

- `-f`: اعتبر أخطاء الخادم فشلًا، ولا تحفظ صفحة خطأ بدل المفتاح.
- `-s`: الوضع الصامت.
- `-S`: اعرض رسالة الخطأ رغم الوضع الصامت.
- `-L`: اتبع التحويلات إلى رابط آخر إن وجدت.
- `-o`: حدد مكان حفظ الملف.

المفتاح لا يمنح Docker صلاحيات على النظام. وظيفته تمكين APT من التأكد أن الحزم صادرة فعلًا عن Docker ولم يتم تعديلها.

اجعل المفتاح قابلًا للقراءة:

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

- `chmod`: تغيير الصلاحيات.
- `a+r`: إضافة صلاحية القراءة للمالك والمجموعة وباقي المستخدمين.

تحقق من الملف وصلاحياته:

```bash
ls -l /etc/apt/keyrings/docker.asc
```

نتيجة مناسبة تكون قريبة من:

```text
-rw-r--r-- 1 root root ... /etc/apt/keyrings/docker.asc
```

---

## 7. إضافة مستودع Docker الرسمي

لـDebian 13 بمعمارية `amd64`:

```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

شرح السطر:

- `deb`: المستودع يقدم حزم Debian جاهزة.
- `arch=amd64`: استخدم الحزم المناسبة لمعمارية النظام.
- `signed-by=...`: تحقق من الحزم باستخدام مفتاح Docker المحدد فقط.
- `trixie`: الحزم الخاصة بـDebian 13.
- `stable`: قناة الإصدارات المستقرة.
- `|`: تمرير ناتج الأمر الموجود على اليسار إلى الأمر الموجود على اليمين.
- `sudo tee`: كتابة النص في ملف محمي بصلاحيات المسؤول.
- `> /dev/null`: إخفاء النسخة التي يطبعها `tee`، دون إخفاء الأخطاء.

استخدمنا `sudo tee` لأن `sudo echo ... > file` لا يرفع صلاحيات عملية إعادة التوجيه `>` نفسها.

تحقق من محتوى الملف:

```bash
cat /etc/apt/sources.list.d/docker.list
```

يجب أن يظهر:

```text
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable
```

> إذا كان الإصدار أو المعمارية مختلفين، لا تنسخ قيم `trixie` و`amd64` عشوائيًا. استخدم القيم التي عرضها نظامك.

---

## 8. تحديث فهرس APT بعد إضافة المستودع

```bash
sudo apt update
```

هذا الأمر لا يثبت Docker؛ بل ينزّل قائمة الحزم المتاحة من جميع المستودعات المسجلة.

يجب أن ترى سطرًا يحتوي:

```text
https://download.docker.com/linux/debian
```

تحقق أن حزمة Docker ستأتي من المصدر الرسمي:

```bash
apt-cache policy docker-ce
```

يجب أن ترى:

- قيمة أمام `Candidate`.
- المصدر `https://download.docker.com/linux/debian`.
- الإصدار المناسب لـDebian 13 Trixie.

---

## 9. تثبيت Docker Engine والمكونات المطلوبة

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

وظيفة كل حزمة:

| الحزمة | الوظيفة |
|---|---|
| `docker-ce` | Docker Engine وخدمة `dockerd` |
| `docker-ce-cli` | أوامر `docker` التي يستخدمها المطور |
| `containerd.io` | إدارة دورة حياة الحاويات بمستوى منخفض |
| `docker-buildx-plugin` | البناء الحديث باستخدام BuildKit والبناء المتقدم |
| `docker-compose-plugin` | يضيف الأمر `docker compose` لتشغيل عدة خدمات |

سيعرض APT الحزم والمساحة المطلوبة ثم يسأل:

```text
Do you want to continue? [Y/n]
```

اكتب `y` واضغط Enter.

---

## 10. التأكد من تشغيل خدمة Docker

```bash
sudo systemctl status docker --no-pager
```

المطلوب رؤية:

```text
Active: active (running)
```

معاني أهم الحالات:

- `active (running)`: الخدمة تعمل.
- `inactive`: الخدمة موجودة لكنها متوقفة.
- `failed`: فشل تشغيلها ويجب فحص السجلات.
- `enabled`: ستبدأ تلقائيًا مع تشغيل Debian.

لتشغيل الخدمة يدويًا:

```bash
sudo systemctl start docker
```

لإيقافها:

```bash
sudo systemctl stop docker
```

لإعادة تشغيلها:

```bash
sudo systemctl restart docker
```

لتفعيل التشغيل التلقائي:

```bash
sudo systemctl enable docker
```

لعرض آخر سجلات الخدمة عند وجود مشكلة:

```bash
sudo journalctl -u docker --no-pager -n 100
```

---

## 11. التحقق من Client وServer

```bash
sudo docker version
```

يجب أن تظهر فقرتان:

- `Client`: برنامج الأوامر.
- `Server`: Docker Engine الذي ينفذ الأوامر.

ظهور Client فقط مع خطأ في Server يعني عادة أن الخدمة متوقفة أو أن المستخدم لا يستطيع الوصول إلى Docker socket.

---

## 12. تشغيل Docker بدون sudo

أضف المستخدم الحالي إلى مجموعة `docker`:

```bash
sudo usermod -aG docker "$USER"
```

- `usermod`: تعديل المستخدم.
- `-G docker`: تحديد مجموعة Docker كمجموعة إضافية.
- `-a`: الإضافة دون إزالة المجموعات الحالية.
- `$USER`: اسم المستخدم الحالي.

وجود `-a` مهم. حذفها قد يستبدل المجموعات الإضافية الحالية للمستخدم.

فعّل العضوية في Shell جديدة:

```bash
newgrp docker
```

أو اخرج من Debian، ثم من PowerShell نفّذ:

```powershell
wsl --shutdown
```

وبعدها افتح Debian مجددًا.

تحقق من مجموعات المستخدم:

```bash
groups
```

يجب أن يظهر اسم المجموعة `docker`.

### تنبيه أمني

عضوية مجموعة `docker` تمنح صلاحيات قوية جدًا وقريبة عمليًا من صلاحيات `root`. لا تضف مستخدمًا غير موثوق إلى هذه المجموعة.

---

## 13. الاختبار النهائي

تحقق من الإصدارات:

```bash
docker --version
docker compose version
docker buildx version
```

اختبر الاتصال بالمحرك:

```bash
docker info
```

شغّل حاوية الاختبار الرسمية:

```bash
docker run --rm hello-world
```

ما الذي يحدث هنا؟

1. يبحث Docker عن image باسم `hello-world` محليًا.
2. إن لم يجدها، ينزّلها من registry.
3. ينشئ container منها.
4. يشغّل البرنامج الموجود داخلها.
5. يطبع رسالة النجاح.
6. الخيار `--rm` يحذف الـcontainer بعد انتهائه، لكنه لا يحذف الـimage.

تحقق من الصور الموجودة:

```bash
docker image ls
```

وتحقق من جميع الحاويات، بما فيها المتوقفة:

```bash
docker container ls -a
```

---

## 14. أين تحفظ مشاريع Docker على WSL2؟

الأفضل إنشاء المشاريع داخل نظام ملفات Debian:

```bash
mkdir -p ~/projects
cd ~/projects
```

الرمز `~` يمثل مجلد المستخدم الحالي، مثل:

```text
/home/ialalawn
```

وبالتالي:

```text
~/projects
```

تعني:

```text
/home/ialalawn/projects
```

الخيار `-p` ينشئ المجلدات الأب إذا لم تكن موجودة، ولا يعطي خطأ إذا كان المجلد موجودًا.

تجنب وضع مشاريع Docker وقواعد البيانات داخل `/mnt/c` قدر الإمكان؛ العمل داخل `/home` يقدم عادة أداءً أفضل وتوافقًا أفضل مع صلاحيات Linux.

لفتح المجلد الحالي في File Explorer:

```bash
explorer.exe .
```

ومن Windows يمكن الوصول إلى ملفات المستخدم عبر:

```text
\\wsl$\Debian\home\USERNAME
```

---

## 15. استخدام VS Code مع WSL2

ثبّت VS Code على Windows، ثم إضافة WSL الرسمية. من داخل مجلد المشروع في Debian نفّذ:

```bash
code .
```

تفتح واجهة VS Code على Windows، بينما الملفات والتيرمنال والأوامر تعمل داخل Debian.

يمكن التحقق من مكان العمل عبر Terminal في VS Code:

```bash
pwd
```

ويفضل أن يكون المسار تحت `/home/USERNAME`.

---

## 16. تحديد موارد WSL2

على Windows أنشئ أو عدّل الملف:

```text
C:\Users\WINDOWS_USERNAME\.wslconfig
```

مثال مناسب لجهاز يحتوي 16GB RAM:

```ini
[wsl2]
memory=6GB
processors=4
swap=2GB
```

ثم طبّق الإعدادات من PowerShell:

```powershell
wsl --shutdown
```

بعدها افتح Debian مجددًا.

يمكن البدء بـ4GB بدل 6GB إذا كانت الخدمات قليلة، ثم الرفع عند الحاجة. WordPress وMariaDB وNginx للتطوير غالبًا لا تحتاج تخصيصًا ضخمًا.

---

## 17. أوامر Docker الأساسية بعد التثبيت

### الصور Images

```bash
docker image ls
docker pull IMAGE_NAME
docker build -t IMAGE_NAME:TAG .
docker image inspect IMAGE_NAME
docker image rm IMAGE_NAME
```

### الحاويات Containers

```bash
docker container ls
docker container ls -a
docker run IMAGE_NAME
docker stop CONTAINER_NAME
docker start CONTAINER_NAME
docker restart CONTAINER_NAME
docker logs CONTAINER_NAME
docker exec -it CONTAINER_NAME sh
docker container rm CONTAINER_NAME
```

### Docker Compose

```bash
docker compose up
docker compose up --build
docker compose up -d
docker compose ps
docker compose logs
docker compose down
```

- `--build`: أعد بناء الصور قبل التشغيل.
- `-d`: شغّل في الخلفية Detached mode.
- `down`: أوقف واحذف حاويات وشبكة المشروع الافتراضية، لكنه لا يحذف volumes إلا إذا أضفت `-v`.

### الشبكات والـvolumes

```bash
docker network ls
docker volume ls
docker volume inspect VOLUME_NAME
```

---

## 18. التحديثات المستقبلية

لتحديث فهرس الحزم ثم تحديث حزم Docker مع بقية النظام:

```bash
sudo apt update
sudo apt upgrade
```

تحقق من الإصدار بعد التحديث:

```bash
docker version
docker compose version
```

تحديث الحزم لا يحذف الصور أو الحاويات أو الـvolumes عادةً، لكن يفضل دائمًا وجود نسخة احتياطية من البيانات المهمة.

---

## 19. تنظيف الموارد غير المستخدمة

اعرض استهلاك Docker للقرص:

```bash
docker system df
```

احذف الحاويات المتوقفة والشبكات والصور غير المستخدمة بحذر:

```bash
docker system prune
```

لا تستخدم الخيارات التي تحذف جميع الصور أو الـvolumes قبل فهم تأثيرها. بيانات MariaDB وWordPress قد تكون موجودة داخل volumes، وحذفها قد يؤدي إلى فقدان البيانات.

---

## 20. إزالة Docker Engine

لإزالة حزم Docker:

```bash
sudo apt remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

إزالة الحزم لا تعني بالضرورة حذف بيانات Docker الموجودة تحت `/var/lib/docker` و`/var/lib/containerd`.

لا تحذف مجلدات البيانات يدويًا إلا إذا كنت متأكدًا أنك تريد فقدان جميع الصور والحاويات والـvolumes والبيانات المرتبطة بها.

لإزالة ملف المستودع والمفتاح فقط بعد إلغاء التثبيت:

```bash
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/apt/keyrings/docker.asc
sudo apt update
```

نفّذ أوامر الحذف فقط عند الحاجة الفعلية وبعد التحقق من المسارات.

---

## 21. أشهر المشاكل وحلولها

### Permission denied عند تشغيل Docker

مثال:

```text
permission denied while trying to connect to the Docker daemon socket
```

تحقق من عضوية المجموعة:

```bash
groups
```

إن لم تظهر `docker`:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

### Cannot connect to the Docker daemon

تحقق من الخدمة:

```bash
sudo systemctl status docker --no-pager
```

ثم شغّلها عند الحاجة:

```bash
sudo systemctl start docker
```

### `systemctl` لا يعمل في WSL

تحقق أولًا من PID 1:

```bash
ps -p 1 -o comm=
```

إذا لم تكن النتيجة `systemd`، فقد تحتاج تفعيله في إعداد WSL. في توزيعات WSL الحديثة يكون systemd متاحًا عادة، ولا تعدّل الإعداد ما دام `systemctl status docker` يعمل عندك.

### المستودع أو المفتاح يعطي خطأ

تحقق من:

```bash
cat /etc/apt/sources.list.d/docker.list
ls -l /etc/apt/keyrings/docker.asc
```

وتأكد أن الاسم الرمزي ومعمارية النظام صحيحان:

```bash
. /etc/os-release && echo "$VERSION_CODENAME"
dpkg --print-architecture
```

### المنفذ مستخدم مسبقًا

إذا ظهر خطأ مثل:

```text
port is already allocated
```

تحقق من الحاويات العاملة:

```bash
docker ps
```

ثم غيّر المنفذ المضيف أو أوقف الخدمة التي تستخدمه.

### امتلاء القرص

```bash
docker system df
df -h
```

نظّف فقط الموارد التي تعرف أنها غير مطلوبة، ولا تحذف volumes الخاصة بقواعد البيانات عشوائيًا.

---

## 22. علاقتها بمشروع Inception

تثبيت Docker هو تجهيز لبيئة العمل، وليس الجزء الأساسي من مشروع Inception. بعده يبدأ العمل الفعلي عادةً في:

- كتابة Dockerfiles للخدمات المطلوبة.
- بناء images بدل الاعتماد على صور خدمات جاهزة، حسب نص الـsubject.
- ربط Nginx وWordPress وMariaDB عبر Docker Compose.
- إنشاء شبكة وvolumes دائمة.
- إدارة المتغيرات والأسرار والشهادات.
- إنشاء Makefile للتشغيل والإيقاف والتنظيف.

إذا كان الـsubject يشترط إنجاز المشروع داخل Virtual Machine، فإن WSL2 ممتاز للتعلم والتطوير، لكن يجب إجراء اختبار نهائي داخل VM مطابقة لشروط المشروع قبل التقييم.

شروط Inception قد تختلف حسب نسخة الـsubject؛ المرجع النهائي هو ملف الـsubject الممنوح لك.

---

## 23. قائمة تحقق نهائية

استخدم هذه القائمة للتأكد أن البيئة جاهزة:

- [ ] Debian يعمل على WSL2 أو VM أو الجهاز الأصلي.
- [ ] `dpkg --print-architecture` يعرض المعمارية المتوقعة.
- [ ] مفتاح Docker موجود داخل `/etc/apt/keyrings/docker.asc`.
- [ ] مستودع Docker الرسمي موجود داخل `docker.list`.
- [ ] `sudo apt update` لا يعرض خطأ للمستودع.
- [ ] حزم Docker Engine وCLI وcontainerd وBuildx وCompose مثبّتة.
- [ ] `systemctl status docker` يعرض `active (running)`.
- [ ] `docker version` يعرض Client وServer.
- [ ] المستخدم عضو في مجموعة `docker`.
- [ ] `docker compose version` يعمل.
- [ ] `docker run --rm hello-world` يطبع رسالة نجاح.
- [ ] المشاريع محفوظة تحت `/home/USERNAME/projects` على WSL2.

---

## 24. المراجع الرسمية

- Docker: تثبيت Docker Engine على Debian: https://docs.docker.com/engine/install/debian/
- Docker: خطوات ما بعد التثبيت على Linux: https://docs.docker.com/engine/install/linux-postinstall/
- Docker Compose: https://docs.docker.com/compose/
- Microsoft WSL: https://learn.microsoft.com/windows/wsl/
- Microsoft: أوامر WSL الأساسية: https://learn.microsoft.com/windows/wsl/basic-commands

---

آخر تحديث للمرجع: 4 أغسطس 2026.
