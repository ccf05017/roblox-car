# Roblox Car: 우주 레이스

우주 트랙에서 컴퓨터 차와 3바퀴를 겨루는 로블록스 자동차 경주 게임입니다.
"아바타톤 로블록스편" 멘토 지원용 데모로 만들었습니다. 지원 조건과 행사 내용은 [`docs/context.md`](docs/context.md)에 있습니다.

AI(Claude Code)로 코드를 짜고, 차 모델은 VARCO 3D로 만들었습니다.
조명을 켠 우주에서 VARCO가 텍스처까지 그린 호버카가 어두운 보라색 도로 위를 달립니다.
별과 행성은 여전히 단순한 도형입니다. 노란 별 하나를 여러 번 찍고, 행성은 단색 공으로 그렸습니다.

## 플레이하기

1. Roblox Studio에서 `Place1.rbxl`을 엽니다.
2. **Home** 탭에서 **Play**를 누릅니다.
3. 게임 화면을 한 번 클릭해서 키 입력이 게임으로 가게 합니다.
4. 3, 2, 1, GO! 다음에 출발합니다.

| 키 | 동작 |
| --- | --- |
| W 또는 ↑ | 가속 |
| S 또는 ↓ | 브레이크, 멈춘 상태에서는 후진 |
| A 또는 ← | 왼쪽으로 꺾기 |
| D 또는 → | 오른쪽으로 꺾기 |

왼쪽 위에 몇 바퀴째인지, 오른쪽 위에 현재 등수가 나옵니다.
3바퀴를 다 돌면 "1등!" 또는 "2등"이 뜹니다.
내 아바타는 하늘색 호버카 조종석에 앉아서 달립니다. 컴퓨터 차에는 주황 옷을 입은 아바타가 탑니다.

## 개발 환경

| 도구 | 하는 일 |
| --- | --- |
| Roblox Studio | 게임 실행과 편집. 맵 파일은 `Place1.rbxl` 하나입니다. |
| [Rojo](https://rojo.space) 7.7 | `src/` 폴더의 코드를 Studio로 실시간 동기화합니다. 매핑은 `default.project.json`에 있습니다. |
| Roblox Studio MCP | AI가 Studio에서 코드를 실행하고 플레이 테스트를 돌립니다. |
| VARCO 3D MCP | AI가 텍스트로 이미지와 3D 모델을 만듭니다. |
| uv | 메시 정리 스크립트를 Python 3.12로 실행합니다. |

MCP 서버 설정은 `.mcp.json`에 있습니다.

코드를 고칠 때는 다음 순서로 합니다.

1. 터미널에서 `rojo serve`를 실행합니다.
2. Studio의 Rojo 플러그인에서 **Connect**를 누릅니다.
3. `src/` 아래 파일을 저장하면 Studio에 바로 반영됩니다.

Rojo는 `src/`와 연결된 세 폴더만 덮어씁니다. Studio에서 직접 넣은 차 모델 같은 것은 `Place1.rbxl`에 저장되고 Rojo가 건드리지 않습니다.

## 구조

레이스는 플레이어 컴퓨터(클라이언트)에서 돕니다. 서버 스크립트는 아바타를 불러오는 일만 합니다.

```
src/
├── shared/                 (ReplicatedStorage.Shared)
│   ├── Track.luau          트랙 모양, 위치 → 트랙 위 거리 변환
│   ├── CarPhysics.luau     차 한 대를 1/60초만큼 움직이는 순수 함수
│   └── AiDriver.luau       컴퓨터 차의 핸들과 가속 결정
├── client/                 (StarterPlayerScripts.Client)
│   ├── World.luau          조명, 도로, 별, 행성, 하늘 만들기
│   ├── Rider.luau          아바타를 차 조종석에 앉히기
│   └── Race.client.luau    레이스 진행, 키보드 입력, 카메라, 화면 표시
└── server/                 (ServerScriptService.Server)
    └── Avatars.server.luau 내 아바타와 컴퓨터 탑승자 만들기
tests/                      (ReplicatedStorage.Tests) 플레이 중에 돌리는 시나리오 테스트
tools/decimate_mesh.py      VARCO 메시를 텍스처째 Roblox에 맞게 줄이는 스크립트
tools/studio_sync.luau      Rojo 없이 src/와 tests/를 Studio에 복사하는 스크립트
assets/varco/               VARCO 원본 콘셉트 이미지와 정리한 차 메시
```

### 트랙

`Track.SPEC`은 L자 모양 꼭짓점 6개와 크기 배율(`scale = 200`)로 트랙을 정의합니다.
`Track.build`는 꼭짓점 사이를 직선으로, 모서리를 반지름 60의 곡선으로 이어서 점 목록을 만듭니다. 한 바퀴는 약 6245 스터드입니다.
`Track.project`는 아무 위치나 "출발선에서 몇 스터드 왔는지"와 "중앙선에서 얼마나 벗어났는지"로 바꿉니다. 바퀴 수, 등수, 벽 충돌이 모두 이 값을 씁니다.

### 차 움직임

차는 Roblox 물리 엔진을 쓰지 않습니다. 고정(Anchored)된 모델을 매 프레임 `PivotTo`로 옮깁니다.
물리 차는 뒤집히거나 미끄러지는데, 이 정도 게임에는 그런 움직임이 필요 없습니다.

`CarPhysics.step(상태, 입력, 시간, 트랙)`은 새 상태를 돌려주는 함수입니다.
상태는 위치, 방향, 속도, 누적 거리 네 값입니다. 입력은 가속(-1~1)과 핸들(-1~1) 두 값입니다.
차가 도로 끝에 닿으면 벽처럼 막히고 속도가 줄어듭니다.

플레이어 차와 컴퓨터 차는 같은 함수로 움직입니다. 입력을 키보드에서 받는지 `AiDriver`에서 받는지만 다릅니다.
`AiDriver`는 속도에 비례해서 앞쪽 트랙 지점을 보고 그쪽으로 핸들을 꺾습니다. 코너에서는 가속을 줄입니다.

### 아바타 탑승

`Players.CharacterAutoLoads`는 `Place1.rbxl`에서 꺼져 있습니다. 그래서 `Avatars.server.luau`가 플레이어가 들어올 때 `LoadCharacter`로 아바타를 직접 만듭니다.
같은 스크립트가 주황 옷을 입은 기본 아바타 `AiRider`를 `ReplicatedStorage`에 만들어 둡니다. `Race.client.luau`는 이것을 복제해서 컴퓨터 차에 태웁니다.

`Rider.seat(아바타, 차)`는 다음을 합니다.

1. 아바타의 `HumanoidRootPart`를 차 몸체에 `Weld`로 붙입니다. 위치는 조종석 높이(`COCKPIT`)라서 상체만 지붕 위로 나옵니다.
2. 앉은 자세 애니메이션 하나만 재생합니다.

로블록스 기본 `Animate` 스크립트는 지웁니다. 이 스크립트를 두면 앉은 자세 위에 다른 애니메이션이 겹쳐 재생됩니다.
차는 고정된 채 `PivotTo`로 움직이고, 붙은 아바타는 같은 프레임에 함께 움직입니다.

### 레이스 진행

`Race.client.luau`는 레이스를 세 단계로 나눕니다.

```
Countdown (3초) → Racing → Finished
```

시뮬레이션은 화면 프레임과 상관없이 1/60초 단위로 돌아서, 컴퓨터 성능이 달라도 같은 결과가 나옵니다.
누적 거리가 트랙 길이를 넘을 때마다 한 바퀴로 셉니다. 플레이어가 3바퀴를 돌면 결과를 띄웁니다.

### 차 모델 (VARCO)

1. VARCO 3D에서 텍스트로 하얀 UFO 모양 호버카 이미지를 만들었습니다(`assets/varco/car-concept.png`).
2. EditImage로 이 이미지를 다시 칠했습니다. 몸체는 하늘색, 줄무늬는 노란색, 지느러미는 주황색이고 숫자 1을 넣었습니다(`assets/varco/car-concept-color.png`).
3. 칠한 이미지로 Generate3D를 텍스처 옵션을 켜고 돌렸습니다. 무료 등급에서는 면 50만 개, 텍스처 4096 크기로 고정됩니다.
4. `tools/decimate_mesh.py`로 면 9000개, 텍스처 1024 크기로 줄였습니다. UV를 그대로 두기 때문에 텍스처가 벗겨지지 않습니다. 줄이기 전에 이음새 꼭짓점을 붙여서 모델에 금이 가지 않게 했습니다.
5. Studio **File → Import**로 `assets/varco/car.glb`를 가져와 `ReplicatedStorage.Assets.Car`에 넣었습니다. 모델은 텍스처를 입은 MeshPart `Body` 하나입니다.
6. 게임이 시작되면 이 모델을 두 번 복제합니다. 색을 따로 칠하지 않으므로 지금은 플레이어 차와 컴퓨터 차가 똑같이 생겼습니다. 이 점은 알려진 한계입니다.

메시를 다시 줄이려면 다음 명령을 실행합니다.

```sh
uv run --python 3.12 --with trimesh --with pymeshlab --with pillow --with scipy --with networkx python tools/decimate_mesh.py IN.glb OUT.glb --faces 9000 --texture 1024
```

### 숫자 조절

| 바꾸고 싶은 것 | 파일 | 값 |
| --- | --- | --- |
| 트랙 길이 | `src/shared/Track.luau` | `scale` (기본 200) |
| 핸들 민감도 | `src/shared/CarPhysics.luau` | `TURN_RATE` (기본 2.2) |
| 최고 속도 | `src/shared/CarPhysics.luau` | `MAX_SPEED` (기본 120) |
| 컴퓨터 차 속도 | `src/shared/AiDriver.luau` | `MAX_THROTTLE` (기본 0.88) |
| 바퀴 수 | `src/client/Race.client.luau` | `LAPS` (기본 3) |

## 테스트

`tests/`의 시나리오 테스트는 Studio 플레이 중에 클라이언트에서 돌립니다. 각 파일은 `PASS`/`FAIL` 줄을 돌려주는 함수를 반환합니다.

| 파일 | 확인하는 것 |
| --- | --- |
| `tests/Riders.spec.luau` | 두 아바타의 앉은 자세, 달리는 동안 자리 유지 |
| `tests/Look.spec.luau` | 조명 값, 도로 색, 외곽선(`Highlight`) 없음, 두 차의 텍스처 |

1. Rojo로 연결하거나 `tools/studio_sync.luau`로 코드를 Studio에 복사합니다.
2. **Play**를 누릅니다.
3. Studio MCP의 `execute_luau`(Client)나 명령 줄에서 다음을 실행합니다.

```lua
print(require(game.ReplicatedStorage.Tests["Riders.spec"])())
print(require(game.ReplicatedStorage.Tests["Look.spec"])())
```

`tools/studio_sync.luau`는 Rojo 플러그인의 Connect 버튼을 누를 사람이 없을 때 씁니다. 저장소 루트에서 `python3 -m http.server 34877 --bind 127.0.0.1`을 실행한 다음, 스크립트를 Studio Edit 모드에서 실행합니다. `default.project.json`의 폴더를 Rojo와 같은 이름 규칙으로 복사하고, 파일이 없어진 스크립트는 지웁니다.

## 버전 기록

### 0.3: 텍스처 차와 조명

- 조명을 켰습니다. 차와 도로에 빛과 그림자가 생깁니다.
- 차 모델을 VARCO에서 텍스처까지 입혀 다시 만들었습니다. 하늘색 몸체에 노란 줄무늬, 숫자 1, 주황 지느러미가 그려져 있습니다.
- 도로를 어두운 보라색으로 바꿨습니다. 하늘색 차와 도로의 밝기 대비가 1.29:1에서 3.14:1로 커졌습니다.
- `tools/decimate_mesh.py`가 메시를 줄일 때 텍스처를 지우지 않습니다. 전에는 UV와 텍스처를 지워서 차가 하얀 단색이 되었습니다.
- 화면 모습을 확인하는 시나리오 테스트 12개(`tests/Look.spec.luau`)를 추가했습니다.

알려진 한계는 다음과 같습니다.

- 플레이어 차와 컴퓨터 차가 똑같이 생겼습니다.

### 0.2: 아바타 탑승

- 내 아바타가 호버카 조종석에 앉아서 달립니다. 상체만 지붕 위로 보입니다.
- 컴퓨터 차에도 주황 옷을 입은 아바타가 탑니다.
- 탑승을 확인하는 시나리오 테스트 15개를 추가했습니다.

### 0.1: 달리는 MVP

개발 환경을 세팅한 다음 처음 만든 플레이 가능한 버전입니다.

- 플레이어 차 1대와 컴퓨터 차 1대가 3바퀴를 겨룹니다.
- 직선과 코너가 있는 L자 우주 트랙이 있습니다. 장애물은 없습니다.
- 컴퓨터 차는 한 바퀴에 약 60초가 걸립니다(Studio 플레이 테스트에서 측정).
- 카운트다운, 바퀴 수, 등수, 결과 화면을 보여 줍니다.
- 차 모델은 VARCO 3D로 만든 호버카 하나를 색만 바꿔서 씁니다.

알려진 한계는 다음과 같습니다.

- 핸들이 민감합니다.
- 다시 하기 버튼이 없습니다. 다시 하려면 Stop 후 Play를 누릅니다.
- 소리가 없습니다.
