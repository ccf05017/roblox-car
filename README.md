# Roblox Car: 우주 레이스

우주 트랙에서 컴퓨터 차와 3바퀴를 겨루는 로블록스 자동차 경주 게임입니다.
"아바타톤 로블록스편" 멘토 지원용 데모로 만들었습니다. 지원 조건과 행사 내용은 [`docs/context.md`](docs/context.md)에 있습니다.

AI(Claude Code)로 코드를 짜고, 차 모델은 VARCO 3D로 만들었습니다.
일부러 초등학생 그림 같은 싸구려 느낌을 냈습니다. 납작한 도형, 단색, 노란 별 하나를 여러 번 찍은 배경입니다.

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
아바타는 나오지 않고 카메라가 차를 따라갑니다.

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

게임 전체가 플레이어 컴퓨터(클라이언트)에서 돕니다. 서버 스크립트는 없습니다.

```
src/
├── shared/                 (ReplicatedStorage.Shared)
│   ├── Track.luau          트랙 모양, 위치 → 트랙 위 거리 변환
│   ├── CarPhysics.luau     차 한 대를 1/60초만큼 움직이는 순수 함수
│   └── AiDriver.luau       컴퓨터 차의 핸들과 가속 결정
├── client/                 (StarterPlayerScripts.Client)
│   ├── World.luau          도로, 별, 행성, 하늘 만들기
│   └── Race.client.luau    레이스 진행, 키보드 입력, 카메라, 화면 표시
└── server/                 비어 있음
tools/decimate_mesh.py      VARCO 메시를 Roblox에 맞게 줄이는 스크립트
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

### 레이스 진행

`Race.client.luau`는 레이스를 세 단계로 나눕니다.

```
Countdown (3초) → Racing → Finished
```

시뮬레이션은 화면 프레임과 상관없이 1/60초 단위로 돌아서, 컴퓨터 성능이 달라도 같은 결과가 나옵니다.
누적 거리가 트랙 길이를 넘을 때마다 한 바퀴로 셉니다. 플레이어가 3바퀴를 돌면 결과를 띄웁니다.

### 차 모델 (VARCO)

1. VARCO 3D에서 텍스트 → 이미지 → 3D 모델 순서로 하얀 UFO 모양 호버카를 만들었습니다.
2. 결과 메시가 너무 커서(면 50만 개) `tools/decimate_mesh.py`로 면 9000개로 줄였습니다. 줄이기 전에 이음새 꼭짓점을 붙여서 모델에 금이 가지 않게 했습니다.
3. Studio **File → Import**로 `assets/varco/car.glb`를 가져와 `ReplicatedStorage.Assets.Car`에 넣었습니다.
4. 게임이 시작되면 이 모델을 두 번 복제해서 플레이어 차는 하늘색, 컴퓨터 차는 주황색으로 칠합니다.

메시를 다시 줄이려면 다음 명령을 실행합니다.

```sh
uv run --python 3.12 --with trimesh --with fast-simplification python tools/decimate_mesh.py IN.glb OUT.glb --faces 9000
```

### 숫자 조절

| 바꾸고 싶은 것 | 파일 | 값 |
| --- | --- | --- |
| 트랙 길이 | `src/shared/Track.luau` | `scale` (기본 200) |
| 핸들 민감도 | `src/shared/CarPhysics.luau` | `TURN_RATE` (기본 2.2) |
| 최고 속도 | `src/shared/CarPhysics.luau` | `MAX_SPEED` (기본 120) |
| 컴퓨터 차 속도 | `src/shared/AiDriver.luau` | `MAX_THROTTLE` (기본 0.88) |
| 바퀴 수 | `src/client/Race.client.luau` | `LAPS` (기본 3) |

## 버전 기록

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
