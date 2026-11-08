# NevelskyiArt Arkanoid

Арканоїд для Android з анімованою героїнею-талісманом.

- **Героїня збоку екрана** реагує на гру: радіє комбо, сумує, коли губиш м'яч, позує на фінальному кадрі перемоги.
- **4 рівні, 4 образи:** Пляж → Неон-сіті → Космос → Казка. Перевдягання відбувається з анімацією-поворотом.
- **Бонуси:** `W` широка платформа, `×3` мультибол, `S` повільний м'яч, `♥` додаткове життя.
- **Рахунок, комбо, життя, синтезовані звуки** (кнопка 🔊 вимикає звук).
- **Керування:** тапни, щоб запустити м'яч, і веди пальцем по екрану, щоб рухати платформу. На ПК працюють стрілки й пробіл.

## Як отримати APK
Кожен пуш автоматично збирає APK у GitHub Actions:
1. Відкрий вкладку **Releases** у репозиторії (або **Actions → Build Android APK → Artifacts**).
2. Завантаж `NevelskyiArt-Arkanoid.apk` на телефон і встанови його (дозволь встановлення з невідомих джерел).

## Розробка
```bash
npm install
npm run dev            # гра в браузері
npm run android:sync   # зібрати й синхронізувати з Android-проєктом
npx cap open android   # відкрити в Android Studio
```

## Godot 4 версія
Та сама гра на Godot 4.3 (GDScript) лежить у папці `godot/`.
- Відкрий `godot/project.godot` у Godot 4.3+ і натисни ▶.
- APK автоматично збирає workflow **Build Godot Android APK**: файл `NevelskyiArt-Arkanoid-Godot.apk` з'являється в Releases та Artifacts.
- Скрипти: `scripts/main.gd` (гра), `scripts/heroine.gd` (героїня), `scripts/themes.gd` (рівні), `scripts/sfx.gd` (звуки), `scripts/particles.gd` (ефекти).
- Смоук-тест з автопілотом і скріншотами: `godot --path godot res://tests/autotest.tscn -- <папка>`.

## Свої арти
Героїня намальована кодом у `src/heroine.js` (Phaser) і `godot/scripts/heroine.gd` (Godot). Щоб замінити її власними спрайтами, збережи публічні методи `setTheme`, `cheer`, `sad`, `victory`, `surprised`, `changeOutfit`, `tick`. Теми й розкладки рівнів лежать у `src/themes.js`.

NevelskyiArt
