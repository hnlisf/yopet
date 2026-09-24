import {
  ArrowLeftIcon,
  Cross2Icon,
  EnvelopeClosedIcon,
  EyeClosedIcon,
  EyeOpenIcon,
  LockClosedIcon,
  MagicWandIcon,
  MixerHorizontalIcon,
  PlusIcon,
  StarIcon,
} from "@radix-ui/react-icons";
import {
  createContext,
  type CSSProperties,
  type FormEvent,
  type ReactNode,
  useContext,
  useMemo,
  useState,
} from "react";
import { Carousel, FlowStack, KeyboardInput, MobileScroll, type FlowControls, type FlowScreen } from "./mobile";

const asset = (name: string) => `/assets/yopet/${name}`;

type FishParts = {
  body: string;
  tail: string;
  pattern: string;
  color: string;
};

type FishFriend = {
  id: string;
  name: string;
  species: string;
  image?: string;
  parts?: FishParts;
  tone: string;
  custom?: boolean;
};

const initialFish: FishFriend[] = [
  { id: "bubble", name: "泡泡", species: "金鱼", image: "fish-orange.png", tone: "暖橙" },
  { id: "peach", name: "桃桃", species: "金鱼", image: "fish-pink.png", tone: "珊瑚粉" },
  { id: "crescent", name: "月牙", species: "金鱼", image: "fish-yellow.png", tone: "月光黄" },
];

type PrototypeState = {
  fish: FishFriend[];
  fishCount: number;
  activeFish: FishFriend;
  hunger: number;
  toast: string;
  addFish: (fish: FishFriend) => void;
  setActiveFish: (fish: FishFriend) => void;
  setHunger: (value: number) => void;
  setToast: (message: string) => void;
};

const PrototypeStateContext = createContext<PrototypeState | null>(null);

function usePrototypeState() {
  const context = useContext(PrototypeStateContext);
  if (!context) throw new Error("usePrototypeState must be used inside Prototype");
  return context;
}

export default function Prototype() {
  const [fish, setFish] = useState<FishFriend[]>(initialFish);
  const [activeFish, setActiveFish] = useState<FishFriend>(initialFish[0]);
  const [hunger, setHunger] = useState(82);
  const [toast, setToast] = useState("");
  const fishCount = fish.length;
  const addFish = (newFish: FishFriend) => setFish((current) => current.length >= 5 ? current : [...current, newFish]);
  const value = useMemo(
    () => ({ fish, fishCount, activeFish, hunger, toast, addFish, setActiveFish, setHunger, setToast }),
    [fish, fishCount, activeFish, hunger, toast],
  );

  return (
    <PrototypeStateContext.Provider value={value}>
      <FlowStack initial={resolveInitialRoute()} />
    </PrototypeStateContext.Provider>
  );
}

const authRoute: FlowScreen = {
  id: "auth",
  render: (flow) => <AuthScreen flow={flow} />,
};

const tankRoute: FlowScreen = {
  id: "tank",
  render: (flow) => <TankScreen flow={flow} />,
};

const adoptRoute: FlowScreen = {
  id: "adopt",
  render: (flow) => <AdoptScreen flow={flow} />,
};

const customRoute: FlowScreen = {
  id: "custom",
  render: (flow) => <CustomFishScreen flow={flow} />,
};

const detailRoute: FlowScreen = {
  id: "detail",
  render: (flow) => <FishDetailScreen flow={flow} />,
};

const decorateRoute: FlowScreen = {
  id: "decorate",
  render: (flow) => <DecorateScreen flow={flow} />,
};

function resolveInitialRoute() {
  const route = new URLSearchParams(window.location.search).get("screen");
  if (route === "tank") return tankRoute;
  if (route === "adopt") return adoptRoute;
  if (route === "custom") return customRoute;
  if (route === "detail") return detailRoute;
  if (route === "decorate") return decorateRoute;
  return authRoute;
}

function ScreenLayer({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`yopet-screen ${className}`}>{children}</section>;
}

function FishArtwork({ fish, className = "", alt }: { fish: FishFriend; className?: string; alt: string }) {
  if (fish.parts) {
    const bodyId = fish.parts.body.replace("custom-body-", "").replace(".png", "");
    const tailId = fish.parts.tail.replace("custom-tail-", "").replace(".png", "");
    const bodyMask = `url("${asset(fish.parts.body)}")`;
    const patternMaskStyle = {
      WebkitMaskImage: bodyMask,
      maskImage: bodyMask,
    } as CSSProperties;

    return (
      <span className={`${className} custom-fish-art body-${bodyId} tail-${tailId} tone-${fish.parts.color}`} role="img" aria-label={alt}>
        <img className="custom-fish-layer custom-color-layer custom-tail-layer" src={asset(fish.parts.tail)} alt="" aria-hidden="true" />
        <img className="custom-fish-layer custom-color-layer custom-body-layer" src={asset(fish.parts.body)} alt="" aria-hidden="true" />
        <img className="custom-fish-layer custom-pattern-layer" src={asset(fish.parts.pattern)} style={patternMaskStyle} alt="" aria-hidden="true" />
      </span>
    );
  }

  return <img className={className} src={asset(fish.image ?? "fish-orange.png")} alt={alt} />;
}

function dismissActiveControl() {
  if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
}

function BackButton({ flow, label = "返回" }: { flow: FlowControls; label?: string }) {
  return (
    <button className="icon-button" type="button" aria-label={label} onClick={() => { dismissActiveControl(); flow.pop(); }}>
      <ArrowLeftIcon />
    </button>
  );
}

function Capacity() {
  const { fishCount } = usePrototypeState();
  return <span className="capacity">{fishCount} / 5</span>;
}

function AuthScreen({ flow }: { flow: FlowControls }) {
  const [mode, setMode] = useState<"sign-in" | "sign-up">("sign-in");
  const [email, setEmail] = useState("hello@yopet.app");
  const [password, setPassword] = useState("yopet2026");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!email.includes("@") || password.length < 6) {
      setError("请填写有效邮箱和至少 6 位密码");
      return;
    }
    setError("");
    dismissActiveControl();
    flow.replace(tankRoute);
  };

  return (
    <ScreenLayer className="auth-screen">
      <MobileScroll className="yopet-scroll auth-scroll">
        <main className="auth-content">
          <div className="auth-brand" aria-label="yopet">yopet</div>
          <header className="auth-intro">
            <h1>回到你的鱼缸</h1>
            <p>一小会儿，也值得慢下来。</p>
          </header>

          <form className="glass-panel auth-panel" onSubmit={submit}>
            <div className="auth-tabs" role="tablist" aria-label="账号方式">
              <button type="button" role="tab" aria-selected={mode === "sign-in"} className={mode === "sign-in" ? "active" : ""} onClick={() => setMode("sign-in")}>登录</button>
              <button type="button" role="tab" aria-selected={mode === "sign-up"} className={mode === "sign-up" ? "active" : ""} onClick={() => setMode("sign-up")}>注册</button>
            </div>

            <label className="field-label" htmlFor="auth-email">
              <span><EnvelopeClosedIcon />邮箱</span>
              <KeyboardInput id="auth-email" type="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="name@example.com" autoComplete="email" />
            </label>

            <label className="field-label" htmlFor="auth-password">
              <span><LockClosedIcon />密码</span>
              <span className="password-field">
                <KeyboardInput id="auth-password" type={showPassword ? "text" : "password"} value={password} onChange={(event) => setPassword(event.target.value)} autoComplete={mode === "sign-in" ? "current-password" : "new-password"} />
                <button type="button" aria-label={showPassword ? "隐藏密码" : "显示密码"} onClick={() => setShowPassword((shown) => !shown)}>
                  {showPassword ? <EyeClosedIcon /> : <EyeOpenIcon />}
                </button>
              </span>
            </label>

            {error ? <p className="form-message" role="alert">{error}</p> : null}

            <button className="primary-button" type="submit">{mode === "sign-in" ? "登录" : "创建账号"}</button>
            <button className="text-button" type="button" onClick={() => setMode(mode === "sign-in" ? "sign-up" : "sign-in")}>
              {mode === "sign-in" ? "第一次来？创建账号" : "已经有账号？直接登录"}
            </button>
          </form>

          <p className="sync-note">你的鱼缸会在设备间同步</p>
        </main>
      </MobileScroll>
    </ScreenLayer>
  );
}

function TankScreen({ flow }: { flow: FlowControls }) {
  const { fish, fishCount, toast, setActiveFish, setToast } = usePrototypeState();

  const openFish = (friend: FishFriend) => {
    setActiveFish(friend);
    dismissActiveControl();
    flow.push(detailRoute);
  };

  return (
    <ScreenLayer className="tank-screen">
      <MobileScroll className="yopet-scroll tank-scroll">
        <main className="tank-content">
          <header className="tank-topbar">
            <div className="wordmark">yopet</div>
            <div className="topbar-actions">
              <Capacity />
              <button className="icon-button soft" type="button" aria-label="鱼缸设置" onClick={() => setToast("设置会在功能开发阶段接入")}><MixerHorizontalIcon /></button>
            </div>
          </header>

          <div className="tank-stage" aria-label={`${fishCount} 条小鱼正在自由游动`}>
            {fish.map((friend, index) => (
              <button
                key={friend.id}
                className={`swimming-fish swim-path-${(index % 5) + 1} swim-depth-${(index % 3) + 1}`}
                type="button"
                data-fish-id={friend.id}
                aria-label={`查看正在游动的${friend.name}`}
                onClick={() => openFish(friend)}
              >
                <FishArtwork fish={friend} className="swim-sprite" alt={`${friend.tone}${friend.species}${friend.name}`} />
              </button>
            ))}
          </div>

          <div className="tank-copy"><strong>{fishCount} 条小鱼正在</strong><span>各自慢慢游。</span></div>
        </main>
      </MobileScroll>

      <nav className="tank-dock glass-panel" aria-label="鱼缸操作">
        <button type="button" onClick={() => openFish(fish[0])}><EyeOpenIcon /><span>看看它们</span></button>
        <button className="active" type="button" onClick={() => { dismissActiveControl(); flow.push(adoptRoute); }}><span className="dock-main-icon"><PlusIcon /></span><span>领养一条</span></button>
        <button type="button" onClick={() => { dismissActiveControl(); flow.push(decorateRoute); }}><MagicWandIcon /><span>布置鱼缸</span></button>
      </nav>

      {toast ? <button className="toast" type="button" aria-live="polite" onClick={() => setToast("")}>{toast}</button> : null}
    </ScreenLayer>
  );
}

const species = [
  { id: "goldfish", label: "金鱼", image: "fish-orange.png", tone: "暖橙", note: "圆润花尾，游得从容" },
  { id: "guppy", label: "孔雀鱼", image: "fish-guppy.png", tone: "薄荷蓝", note: "轻盈扇尾，喜欢探索" },
  { id: "betta", label: "斗鱼", image: "fish-betta.png", tone: "珊瑚粉", note: "飘带长鳍，安静自信" },
  { id: "angelfish", label: "神仙鱼", image: "fish-angelfish.png", tone: "蜜糖金", note: "菱形身姿，缓慢升降" },
  { id: "koi", label: "锦鲤", image: "fish-koi.png", tone: "云白橙", note: "修长温和，沉稳巡游" },
  { id: "discus", label: "七彩神仙", image: "fish-discus.png", tone: "霞光粉", note: "圆盘轮廓，悠然转身" },
  { id: "neon", label: "霓虹灯鱼", image: "fish-neon-tetra.png", tone: "电光蓝", note: "小巧灵敏，喜欢群游" },
  { id: "zebra", label: "斑马鱼", image: "fish-zebrafish.png", tone: "水纹蓝", note: "横纹修长，游得轻快" },
  { id: "swordtail", label: "红剑鱼", image: "fish-swordtail.png", tone: "珊瑚红", note: "醒目剑尾，行动利落" },
  { id: "molly", label: "玛丽鱼", image: "fish-molly.png", tone: "夜光紫", note: "圆润背鳍，亲切活泼" },
  { id: "barb", label: "虎皮鱼", image: "fish-tiger-barb.png", tone: "琥珀橙", note: "短身条纹，好奇敏捷" },
  { id: "cory", label: "鼠鱼", image: "fish-corydoras.png", tone: "浅沙金", note: "贴近缸底，慢慢寻宝" },
];

const customBodies = [
  { id: "round", label: "圆润", note: "柔和椭圆", image: "custom-body-round.png" },
  { id: "light", label: "流线", note: "灯鱼式细长", image: "custom-body-light.png" },
  { id: "diamond", label: "菱形", note: "神仙鱼式高身", image: "custom-body-diamond.png" },
  { id: "disc", label: "圆盘", note: "七彩神仙式圆盘", image: "custom-body-disc.png" },
  { id: "torpedo", label: "梭形", note: "斑马鱼式高速身形", image: "custom-body-torpedo.png" },
  { id: "bottom", label: "底栖", note: "鼠鱼式平腹拱背", image: "custom-body-bottom.png" },
  { id: "box", label: "箱形", note: "箱鲀式软方轮廓", image: "custom-body-box.png" },
  { id: "eel", label: "鳗形", note: "鳗鲡式蜿蜒长身", image: "custom-body-eel.png" },
];

const customTails = [
  { id: "petal", label: "花瓣尾", image: "custom-tail-petal.png" },
  { id: "fan", label: "扇形尾", image: "custom-tail-fan.png" },
  { id: "ribbon", label: "飘带尾", image: "custom-tail-ribbon.png" },
];

const customPatterns = [
  { id: "cloud", label: "云锦", image: "custom-pattern-cloud.png" },
  { id: "pearl", label: "珍珠斑", image: "custom-pattern-pearl.png" },
  { id: "tiger", label: "虎纹", image: "custom-pattern-tiger.png" },
  { id: "zebra", label: "横纹", image: "custom-pattern-zebra.png" },
  { id: "neon", label: "霓虹带", image: "custom-pattern-neon.png" },
  { id: "saddle", label: "鞍斑", image: "custom-pattern-saddle.png" },
  { id: "eye", label: "眼斑", image: "custom-pattern-eye.png" },
  { id: "belly", label: "双色腹", image: "custom-pattern-belly.png" },
];

const customColors = [
  { id: "orange", label: "暖橙", swatch: "swatch-orange.png" },
  { id: "yellow", label: "月光黄", swatch: "swatch-yellow.png" },
  { id: "red", label: "朱砂红", swatch: "swatch-pink.png" },
  { id: "coral", label: "珊瑚红", swatch: "swatch-pink.png" },
  { id: "pink", label: "玫瑰粉", swatch: "swatch-pink.png" },
  { id: "green", label: "青苔绿", swatch: "swatch-yellow.png" },
  { id: "mint", label: "薄荷青", swatch: "swatch-yellow.png" },
  { id: "teal", label: "湖水青", swatch: "swatch-orange.png" },
  { id: "cyan", label: "晴空蓝", swatch: "swatch-orange.png" },
  { id: "blue", label: "深海蓝", swatch: "swatch-orange.png" },
  { id: "violet", label: "鸢尾紫", swatch: "swatch-pink.png" },
  { id: "indigo", label: "靛青", swatch: "swatch-orange.png" },
];

function AdoptScreen({ flow }: { flow: FlowControls }) {
  const { fishCount, addFish, setActiveFish, setToast } = usePrototypeState();
  const [selectedSpecies, setSelectedSpecies] = useState("goldfish");
  const [name, setName] = useState("泡泡");
  const selectedSpeciesData = species.find((item) => item.id === selectedSpecies) ?? species[0];

  const confirm = () => {
    if (fishCount >= 5) return;
    const friend: FishFriend = {
      id: `${selectedSpecies}-${Date.now()}`,
      name: name.trim() || "新朋友",
      species: selectedSpeciesData.label,
      image: selectedSpeciesData.image,
      tone: selectedSpeciesData.tone,
    };
    addFish(friend);
    setActiveFish(friend);
    setToast(`${friend.name}已经住进鱼缸，会和大家一起自由游动`);
    dismissActiveControl();
    flow.pop();
  };

  return (
    <ScreenLayer className="adopt-screen">
      <MobileScroll className="yopet-scroll adopt-scroll">
        <main className="adopt-content">
          <header className="screen-topbar"><BackButton flow={flow} /><h1>领养一条鱼</h1><Capacity /></header>
          <p className="screen-kicker">12 种预设，也可以设计独一无二的新鱼种</p>
          <div className="adopt-hero">
            <img src={asset(selectedSpeciesData.image)} alt={`选择中的${selectedSpeciesData.label}`} />
            <span className="hero-species-tag">{selectedSpeciesData.label} · {selectedSpeciesData.tone}</span>
          </div>

          <section className="glass-panel adoption-panel" aria-label="选择新朋友">
            <header className="catalog-heading"><div><h2>预设鱼种</h2><p>保留真实轮廓，细节轻柔抽象</p></div><span>12 种</span></header>
            <Carousel ariaLabel="鱼种图鉴，可横向滑动" className="species-carousel" contentClassName="species-track" showScrollbar>
              {species.map((item) => (
                <button key={item.id} type="button" className={`species-card ${selectedSpecies === item.id ? "selected" : ""}`} aria-pressed={selectedSpecies === item.id} onClick={() => setSelectedSpecies(item.id)}>
                  <span className="species-image"><img src={asset(item.image)} alt="" /></span><strong>{item.label}</strong>
                </button>
              ))}
            </Carousel>

            <div className="species-summary"><span>{selectedSpeciesData.label}</span><p>{selectedSpeciesData.note}</p></div>
            <button className="custom-entry" type="button" onClick={() => { dismissActiveControl(); flow.push(customRoute); }}>
              <span className="custom-entry-icon"><MagicWandIcon /></span>
              <span><strong>组合式自定义鱼</strong><small>体型、尾鳍、纹样和水彩都由你决定</small></span>
              <PlusIcon />
            </button>

            <label className="field-label adoption-name" htmlFor="fish-name"><span>给它取个名字</span><KeyboardInput id="fish-name" value={name} onChange={(event) => setName(event.target.value)} maxLength={12} /></label>
            <button className="primary-button" type="button" onClick={confirm} disabled={fishCount >= 5}>{fishCount >= 5 ? "鱼缸已经住满了" : "确认放入鱼缸"}</button>
          </section>
        </main>
      </MobileScroll>
    </ScreenLayer>
  );
}

function CustomFishScreen({ flow }: { flow: FlowControls }) {
  const { fishCount, addFish, setActiveFish, setToast } = usePrototypeState();
  const customQuery = new URLSearchParams(window.location.search);
  const [body, setBody] = useState(() => Math.max(0, customBodies.findIndex((item) => item.id === customQuery.get("body"))));
  const [tail, setTail] = useState(() => Math.max(0, customTails.findIndex((item) => item.id === customQuery.get("tail"))));
  const [pattern, setPattern] = useState(() => Math.max(0, customPatterns.findIndex((item) => item.id === customQuery.get("pattern"))));
  const [color, setColor] = useState(() => Math.max(0, customColors.findIndex((item) => item.id === customQuery.get("color"))));
  const [name, setName] = useState("云尾");
  const previewParts: FishParts = {
    body: customBodies[body].image,
    tail: customTails[tail].image,
    pattern: customPatterns[pattern].image,
    color: customColors[color].id,
  };
  const previewFish: FishFriend = {
    id: "custom-preview",
    name: name.trim() || "我的鱼种",
    species: `${customBodies[body].label}${customTails[tail].label}鱼`,
    parts: previewParts,
    tone: customColors[color].label,
    custom: true,
  };

  const confirm = () => {
    if (fishCount >= 5) return;
    const speciesName = name.trim() || "我的鱼种";
    const friend: FishFriend = {
      id: `custom-${Date.now()}`,
      name: speciesName,
      species: `${customBodies[body].label}${customTails[tail].label}鱼`,
      parts: previewParts,
      tone: customColors[color].label,
      custom: true,
    };
    addFish(friend);
    setActiveFish(friend);
    setToast(`${friend.name}已经成为你的专属鱼种`);
    dismissActiveControl();
    flow.replace(tankRoute);
  };

  return (
    <ScreenLayer className="custom-screen">
      <MobileScroll className="yopet-scroll custom-scroll">
        <main className="custom-content">
          <header className="screen-topbar"><BackButton flow={flow} /><h1>设计我的鱼</h1><Capacity /></header>
          <p className="screen-kicker">8 种自然体型 · 8 种鱼类纹样 · 12 种水彩</p>

          <figure className="custom-preview">
            <div className="custom-preview-art">
              <FishArtwork fish={previewFish} className="custom-preview-fish" alt="组合中的自定义鱼" />
            </div>
            <figcaption>{customBodies[body].label}体型 · {customTails[tail].label} · {customPatterns[pattern].label}</figcaption>
          </figure>

          <section className="glass-panel custom-panel" aria-label="组合鱼种外观">
            <TraitChooser label="体型" note={`8 种 · ${customBodies[body].note}`} items={customBodies} selected={body} onSelect={setBody} />
            <TraitChooser label="尾鳍" items={customTails} selected={tail} onSelect={setTail} />
            <TraitChooser label="纹样" note="8 种 · 贴合鱼身" items={customPatterns} selected={pattern} onSelect={setPattern} />

            <fieldset className="color-choices custom-colors">
              <legend><span>水彩</span><small>12 色 · 覆盖冷暖色域</small></legend>
              <div>
                {customColors.map((item, index) => (
                  <button key={item.id} className={`color-choice ${color === index ? "selected" : ""}`} type="button" aria-label={item.label} aria-pressed={color === index} onClick={() => setColor(index)}>
                    <span className="pigment"><img className={`swatch-tone-${item.id}`} src={asset(item.swatch)} alt="" /></span><span>{item.label}</span>
                  </button>
                ))}
              </div>
            </fieldset>

            <label className="field-label adoption-name" htmlFor="custom-fish-name"><span>给新鱼种取个名字</span><KeyboardInput id="custom-fish-name" value={name} onChange={(event) => setName(event.target.value)} maxLength={12} /></label>
            <button className="primary-button" type="button" onClick={confirm} disabled={fishCount >= 5}>{fishCount >= 5 ? "鱼缸已经住满了" : "保存并放入鱼缸"}</button>
          </section>
        </main>
      </MobileScroll>
    </ScreenLayer>
  );
}

function TraitChooser({
  label,
  note,
  items,
  selected,
  onSelect,
}: {
  label: string;
  note?: string;
  items: ReadonlyArray<{ id: string; label: string }>;
  selected: number;
  onSelect: (index: number) => void;
}) {
  return (
    <fieldset className="trait-chooser">
      <legend>{label}{note ? <small>{note}</small> : null}</legend>
      <div>
        {items.map((item, index) => <button key={item.id} type="button" className={selected === index ? "selected" : ""} aria-pressed={selected === index} onClick={() => onSelect(index)}>{item.label}</button>)}
      </div>
    </fieldset>
  );
}

function FishDetailScreen({ flow }: { flow: FlowControls }) {
  const { fish, activeFish, hunger, setHunger } = usePrototypeState();
  const [fed, setFed] = useState(false);
  const feed = () => { setHunger(100); setFed(true); };
  const companions = fish.filter((friend) => friend.id !== activeFish.id);
  const companionOne = companions[0] ?? initialFish[1];
  const companionTwo = companions[1] ?? initialFish[2];

  return (
    <ScreenLayer className="detail-screen">
      <MobileScroll className="yopet-scroll detail-scroll">
        <main className="detail-content">
          <header className="screen-topbar"><BackButton flow={flow} /><h1>看看它们</h1><Capacity /></header>
          <div className="detail-stage">
            <FishArtwork fish={companionOne} className="detail-fish distant one" alt={`远处的${companionOne.name}`} />
            <FishArtwork fish={activeFish} className="detail-fish hero" alt={`${activeFish.tone}${activeFish.species}${activeFish.name}`} />
            <FishArtwork fish={companionTwo} className="detail-fish distant two" alt={`远处的${companionTwo.name}`} />
          </div>

          <section className="glass-panel detail-panel" aria-label={`${activeFish.name}的状态`}>
            <button className="close-detail" type="button" aria-label="关闭详情" onClick={() => { dismissActiveControl(); flow.pop(); }}><Cross2Icon /></button>
            <h2>{activeFish.name}</h2><p className="fish-subtitle">{activeFish.species} · {activeFish.tone}</p>
            <div className="trait-row"><span>{activeFish.custom ? "独一无二" : "好奇"}</span><span>自在</span></div>
            <p className="good-state"><StarIcon />{fed ? "刚刚吃饱，游得很开心" : "今天状态很好"}</p>
            <div className="satiety">
              <div className="satiety-head"><span>饱腹度</span><strong>{hunger}%</strong></div>
              <div className="satiety-track" aria-label={`饱腹度 ${hunger}%`}><span style={{ width: `${hunger}%` }} /></div>
            </div>
            <p className="fish-age">幼鱼 · 第 12 天</p>
            <p className="water-hint">轻点水面，和它打个招呼</p>
            <button className="primary-button" type="button" onClick={feed}>{fed ? "已经喂好了" : "喂食"}</button>
          </section>
        </main>
      </MobileScroll>
    </ScreenLayer>
  );
}

const decorationCategories = ["水草", "石景", "沉木", "背景"] as const;
type DecorationCategory = (typeof decorationCategories)[number];

const decorations = [
  { id: "long", category: "水草", label: "长叶水草", image: "decor-long-plant.png", kind: "object" },
  { id: "round", category: "水草", label: "圆叶水草", image: "decor-round-plant.png", kind: "object" },
  { id: "coral", category: "水草", label: "珊瑚草", image: "decor-coral.png", kind: "object" },
  { id: "ribbon", category: "水草", label: "缎带水草", image: "decor-ribbon-plant.png", kind: "object" },
  { id: "rock", category: "石景", label: "青苔石景", image: "decor-rock.png", kind: "object" },
  { id: "sand", category: "石景", label: "月光砂", image: "decor-sand.png", kind: "object" },
  { id: "arch", category: "石景", label: "月石拱门", image: "decor-arch-rock.png", kind: "object" },
  { id: "pebbles", category: "石景", label: "卵石花园", image: "decor-pebbles.png", kind: "object" },
  { id: "wood", category: "沉木", label: "溪流沉木", image: "decor-driftwood.png", kind: "object" },
  { id: "branch", category: "沉木", label: "枝桠沉木", image: "decor-branch.png", kind: "object" },
  { id: "rootwood", category: "沉木", label: "根系小屋", image: "decor-rootwood.png", kind: "object" },
  { id: "midnight", category: "背景", label: "静谧深海", image: "tank-background.png", kind: "background" },
  { id: "moonlit", category: "背景", label: "月光浅湾", image: "tank-background-moonlit.png", kind: "background" },
  { id: "aurora", category: "背景", label: "青绿极光", image: "tank-background-aurora.png", kind: "background" },
] as const;

function DecorateScreen({ flow }: { flow: FlowControls }) {
  const requestedDecoration = new URLSearchParams(window.location.search).get("decor");
  const initialDecoration = decorations.find((item) => item.id === requestedDecoration) ?? decorations[0];
  const [category, setCategory] = useState<DecorationCategory>(initialDecoration.category);
  const [selected, setSelected] = useState(initialDecoration.id);
  const visibleDecorations = decorations.filter((item) => item.category === category);
  const selectedItem = decorations.find((item) => item.id === selected) ?? decorations[0];
  const chooseCategory = (nextCategory: DecorationCategory) => {
    setCategory(nextCategory);
    setSelected(decorations.find((item) => item.category === nextCategory)?.id ?? "long");
  };

  return (
    <ScreenLayer className="decorate-screen">
      <div className="decorate-tank" aria-hidden="true">
        {selectedItem.kind === "background" ? <img className="decor-background-preview" src={asset(selectedItem.image)} alt="" /> : null}
        <img className="decor-fish orange" src={asset("fish-orange.png")} alt="" />
        <img className="decor-fish pink" src={asset("fish-pink.png")} alt="" />
        {selectedItem.kind === "object" ? <div className="placed-decoration"><img src={asset(selectedItem.image)} alt="" /><span className="handle top" /><span className="handle bottom" /></div> : null}
      </div>

      <MobileScroll className="yopet-scroll drawer-scroll">
        <aside className="glass-panel decor-drawer" aria-label="鱼缸装饰抽屉">
          <button className="drawer-close" type="button" aria-label="关闭布置" onClick={() => { dismissActiveControl(); flow.pop(); }}><Cross2Icon /></button>
          <header><h1>布置鱼缸</h1><p>每类都有不同的水彩预设</p></header>
          <nav className="decor-tabs" aria-label="装饰类型">
            {decorationCategories.map((item) => <button key={item} type="button" className={category === item ? "active" : ""} onClick={() => chooseCategory(item)}>{item}</button>)}
          </nav>
          <div className="decor-category-head"><span>{category}预设</span><small>{visibleDecorations.length} 件</small></div>
          <div className="decor-grid">
            {visibleDecorations.map((item) => (
              <button key={item.id} type="button" className={`${selected === item.id ? "selected" : ""} ${item.kind === "background" ? "background-card" : ""}`} onClick={() => setSelected(item.id)} aria-pressed={selected === item.id}>
                <span><img src={asset(item.image)} alt="" /></span><strong>{item.label}</strong>
              </button>
            ))}
          </div>
          <p className="placed-note">{selectedItem.kind === "background" ? `${selectedItem.label}正在整缸预览` : `${selectedItem.label}已选中 · 可拖到缸中调整`}</p>
          <button className="primary-button" type="button" onClick={() => { dismissActiveControl(); flow.pop(); }}>完成布置</button>
        </aside>
      </MobileScroll>
    </ScreenLayer>
  );
}
