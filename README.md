# Echo Runner — Godot (Tam Port)

`artifacts/echo-runner/src/game/engine.ts` dosyasının birebir Godot 4 portu.

## Orijinal ile eşleşen sistemler

- `keys["KeyA"]` / `keys["Space"]` tarzı klavye takibi (KeyboardEvent.code)
- Echo dalgası, pulse, tehlike, canavar AI
- Engel/coin spawn, checkpoint, parçacık efektleri
- Menü, market, ayarlar, ölüm ekranı
- Canvas shadowBlur → glow çizimi
- Radial/linear gradient echo ve canavar uyarısı
- Kesikli checkpoint çizgileri
- Web Audio müzik (sine 55/82.4/110/146.8 Hz + saw 27.5 Hz)
- `App.tsx` müzik butonu davranışı

## Çalıştırma

Godot 4.2+ → Import → `project.godot` → F5

## Kontroller (orijinal ile aynı)

| Tuş | Aksiyon |
|-----|---------|
| WASD / Ok | Hareket |
| Shift | Sprint |
| Space | Echo |
| Space / Enter (ölünce) | Tekrar oyna |
| M (ölünce) | Ana menü |
| Fare | Menü butonları |
| Dokunmatik | Echo + tıklama |
| Sağ alt 🔇/🔊 | Müzik |

## Dosyalar

```
scripts/
  game_engine.gd    # engine.ts ana portu
  game_constants.gd # sabitler
  canvas_util.gd    # ctx çizim yardımcıları
  music_synth.gd    # Web Audio portu
  oscillator_node.gd
  music_button.gd   # App.tsx butonu
```
