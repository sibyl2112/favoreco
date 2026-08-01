"use client";

import { useMemo, useState } from "react";

type ModeId = "register" | "plan" | "record" | "performanceEdit" | "planEdit";

type Mode = {
  id: ModeId;
  short: string;
  title: string;
  eyebrow: string;
  description: string;
  primary: string;
};

const modes: Mode[] = [
  {
    id: "register",
    short: "公演を登録",
    title: "公演を登録",
    eyebrow: "公演を見つけたとき",
    description: "まずタイトルだけ。必要な情報は、あとから静かに足せます。",
    primary: "公演を保存",
  },
  {
    id: "plan",
    short: "予定を立てる",
    title: "観劇予定を追加",
    eyebrow: "行く日が決まったとき",
    description: "公演情報を引き継いで、日時と会場だけを先に登録します。",
    primary: "予定を保存",
  },
  {
    id: "record",
    short: "観劇記録",
    title: "観劇記録を編集",
    eyebrow: "観劇後に残すとき",
    description: "予定を引き継ぎ、座席・写真・感想・金額を記録できます。",
    primary: "記録を保存",
  },
  {
    id: "performanceEdit",
    short: "公演情報編集",
    title: "公演情報を編集",
    eyebrow: "公式情報を整えるとき",
    description: "会期や会場、公式リンクなど、公演そのものの情報を編集します。",
    primary: "変更を保存",
  },
  {
    id: "planEdit",
    short: "予定を編集",
    title: "観劇予定を編集",
    eyebrow: "予定が変わったとき",
    description: "公演はそのまま、参加する日・時刻・会場だけを更新します。",
    primary: "予定を更新",
  },
];

const sectionRules: Record<
  ModeId,
  { open: string[]; closed: string[]; hidden: string[] }
> = {
  register: {
    open: ["公演基本情報"],
    closed: ["会期・会場", "公演詳細情報", "読み取り情報"],
    hidden: ["参加記録", "やる事リスト", "鑑賞記録", "写真", "感想記録", "集計記録"],
  },
  plan: {
    open: ["公演基本情報", "参加記録"],
    closed: ["やる事リスト", "鑑賞記録", "写真"],
    hidden: ["公演詳細情報", "読み取り情報", "感想記録", "集計記録"],
  },
  record: {
    open: ["公演基本情報", "参加記録", "鑑賞記録", "写真"],
    closed: ["やる事リスト", "感想記録", "集計記録"],
    hidden: ["読み取り情報"],
  },
  performanceEdit: {
    open: ["公演基本情報", "会期・会場"],
    closed: ["公演詳細情報", "読み取り情報"],
    hidden: ["参加記録", "やる事リスト", "鑑賞記録", "写真", "感想記録", "集計記録"],
  },
  planEdit: {
    open: ["公演基本情報", "参加記録"],
    closed: ["やる事リスト", "鑑賞記録", "写真"],
    hidden: ["公演詳細情報", "読み取り情報", "感想記録", "集計記録"],
  },
};

function Field({
  label,
  value,
  required,
}: {
  label: string;
  value: string;
  required?: boolean;
}) {
  return (
    <div className="field">
      <span>{label}</span>
      <strong className={value ? "" : "placeholder"}>{value || "未入力"}</strong>
      {required && <small>必須</small>}
    </div>
  );
}

function CollapsedSection({ title, note }: { title: string; note: string }) {
  return (
    <button className="collapsed" type="button">
      <span>
        <b>{title}</b>
        <small>{note}</small>
      </span>
      <i>＋</i>
    </button>
  );
}

function Phone({ mode }: { mode: Mode }) {
  const isPublic = mode.id === "register" || mode.id === "performanceEdit";
  const isRecord = mode.id === "record";
  const isPlan = mode.id === "plan" || mode.id === "planEdit";

  return (
    <div className="phone-wrap">
      <div className="phone">
        <div className="phone-status">
          <span>12:10</span>
          <span>● ●● 78</span>
        </div>
        <header className="phone-header">
          <button>閉じる</button>
          <div>
            <small>{mode.eyebrow}</small>
            <h3>{mode.title}</h3>
          </div>
          <button className="save">{mode.primary}</button>
        </header>

        <div className="phone-scroll">
          <section className="lead-card">
            <p>{mode.description}</p>
            <div className="weight-key">
              <span><i className="dot heavy" />いま必要</span>
              <span><i className="dot medium" />あとでもOK</span>
              <span><i className="dot light" />必要なときだけ</span>
            </div>
          </section>

          <section className="form-section open-section">
            <div className="section-heading">
              <span className="step">01</span>
              <div><h4>公演基本情報</h4><p>すべての入口で共通</p></div>
              <span className="chevron">⌃</span>
            </div>
            <div className="form-card">
              <Field label="タイトル" value="月影のアトリエ" required />
              <Field label="公演種別" value="観劇" />
              <Field label="公式URL" value={isPublic ? "https://official.example" : ""} />
              <button className="add-fields" type="button">＋ サブタイトル・シリーズを追加</button>
            </div>
          </section>

          {isPublic && (
            <>
              <section className="form-section open-section">
                <div className="section-heading">
                  <span className="step">02</span>
                  <div><h4>会期・会場</h4><p>複数の会場を追加できます</p></div>
                  <span className="chevron">⌃</span>
                </div>
                <div className="form-card schedule-row">
                  <div>
                    <small>東京公演</small>
                    <strong>7/4(土) — 7/19(日)</strong>
                    <span>東京芸術劇場 プレイハウス</span>
                  </div>
                  <button type="button">編集</button>
                </div>
              </section>
              <CollapsedSection title="公演詳細情報" note="主催・公式リンク・出演者・メモ" />
              <CollapsedSection title="読み取り情報" note="OCRで取得した原文を確認" />
            </>
          )}

          {(isPlan || isRecord) && (
            <>
              <section className="form-section open-section">
                <div className="section-heading">
                  <span className="step">02</span>
                  <div><h4>参加記録</h4><p>予定・記録の核になる情報</p></div>
                  <span className="chevron">⌃</span>
                </div>
                <div className="form-card">
                  <Field label="鑑賞日" value="2026年7月4日(土)" required />
                  <Field label="開演" value="18:00" required />
                  <Field label="会場" value="東京芸術劇場" required={!isRecord} />
                </div>
              </section>
              <CollapsedSection title="やる事リスト" note="当日までの準備を追加" />
              <CollapsedSection title="鑑賞記録" note="鑑賞方法・座席・注目した人" />
            </>
          )}

          {isRecord && (
            <>
              <section className="form-section photo-section">
                <div className="section-heading">
                  <span className="step">04</span>
                  <div><h4>写真</h4><p>ポスターも当日の記録も、ここへ</p></div>
                  <span className="photo-count">8 / 12</span>
                </div>
                <div className="photo-grid">
                  {Array.from({ length: 8 }, (_, index) => (
                    <div className={`photo photo-${index + 1}`} key={index}>
                      {index === 7 && <span>＋4<br/><small>さらに見る</small></span>}
                    </div>
                  ))}
                </div>
              </section>
              <CollapsedSection title="感想記録" note="評価・感情タグ・自由メモ" />
              <CollapsedSection title="集計記録" note="金額・レシート読み取り" />
            </>
          )}
          <div className="phone-bottom-space" />
        </div>
        <div className="phone-home" />
      </div>
      <div className="mode-stamp">
        <span>ENTRY MODE</span>
        <strong>{modes.findIndex((item) => item.id === mode.id) + 1}/5</strong>
      </div>
    </div>
  );
}

export default function Home() {
  const [activeMode, setActiveMode] = useState<ModeId>("register");
  const mode = useMemo(
    () => modes.find((item) => item.id === activeMode) ?? modes[0],
    [activeMode],
  );
  const rules = sectionRules[activeMode];

  return (
    <main>
      <nav className="topbar">
        <a className="brand" href="#top">Favoreco <span>FORM CONCEPT</span></a>
        <div>
          <a href="#behavior">見え方の設計</a>
          <a href="#structure">情報構造</a>
        </div>
      </nav>

      <section className="hero" id="top">
        <div className="hero-copy">
          <p className="kicker">UNIFIED THEATER EXPERIENCE FORM</p>
          <h1>ひとつのページ。<br/><em>5つの入口。</em></h1>
          <p className="hero-lead">
            公演を見つけた瞬間から、観劇後の記録まで。
            同じ情報を何度も入力せず、いま必要な項目だけが前に出る編集体験へ。
          </p>
          <div className="mode-picker" aria-label="入口を選択">
            {modes.map((item, index) => (
              <button
                className={item.id === activeMode ? "active" : ""}
                key={item.id}
                onClick={() => setActiveMode(item.id)}
                type="button"
              >
                <span>0{index + 1}</span>{item.short}
              </button>
            ))}
          </div>
          <p className="switch-hint">入口を選ぶと、右の完成イメージが切り替わります。</p>
        </div>
        <Phone mode={mode} />
      </section>

      <section className="behavior" id="behavior">
        <div className="section-intro">
          <p className="kicker">CONTEXT, NOT DIFFERENT FORMS</p>
          <h2>変わるのはページではなく、<br/>情報の<em>優先度</em>。</h2>
          <p>保存先はひとつ。入口とタイミングから、開く・閉じる・隠すを決めます。</p>
        </div>
        <div className="rule-board">
          <div className="rule-title">
            <span>{mode.eyebrow}</span>
            <h3>{mode.title}</h3>
          </div>
          <div className="rule-column open-rule">
            <small>OPEN / すぐ見せる</small>
            {rules.open.map((item) => <span key={item}>{item}</span>)}
          </div>
          <div className="rule-column closed-rule">
            <small>CLOSED / たためる</small>
            {rules.closed.map((item) => <span key={item}>{item}</span>)}
          </div>
          <div className="rule-column hidden-rule">
            <small>HIDDEN / 今は出さない</small>
            {rules.hidden.map((item) => <span key={item}>{item}</span>)}
          </div>
        </div>
      </section>

      <section className="structure" id="structure">
        <div className="section-intro light">
          <p className="kicker">INFORMATION ARCHITECTURE</p>
          <h2>公演と鑑賞を分ける。<br/>でも、操作は途切れさせない。</h2>
        </div>
        <div className="architecture">
          <article className="arch-card public">
            <span className="arch-number">A</span>
            <p>みんなで共有する</p>
            <h3>公演情報</h3>
            <ul>
              <li><b>重</b> タイトル・種別・ビジュアル</li>
              <li><b>中</b> 会期・会場・公式URL</li>
              <li><b>軽</b> 制作・SNS・出演者・メモ</li>
            </ul>
          </article>
          <div className="arch-bridge">
            <span>同じ公演を参照</span>
            <i>→</i>
            <small>二重入力しない</small>
          </div>
          <article className="arch-card private">
            <span className="arch-number">B</span>
            <p>自分だけに残す</p>
            <h3>鑑賞情報</h3>
            <ul>
              <li><b>重</b> 鑑賞日・開演・会場</li>
              <li><b>中</b> 座席・方法・注目した人</li>
              <li><b>軽</b> 写真・感想・金額</li>
            </ul>
          </article>
          <article className="arch-card ticket">
            <span className="arch-number">C</span>
            <p>保存後につなぐ</p>
            <h3>チケット</h3>
            <p className="ticket-copy">フォームからは切り離し、登録完了後の次の行動として案内。</p>
            <div className="after-save">
              <button type="button">予定を立てる</button>
              <button type="button">チケットを手配する</button>
              <button type="button">完了</button>
            </div>
          </article>
        </div>
      </section>

      <section className="photo-principle">
        <div>
          <p className="kicker">PHOTO PRINCIPLE</p>
          <h2>写真は独立。<br/>静かに、4列で。</h2>
          <p>
            アイキャッチ、ポスター、事前の資料、観劇後の写真を区別しすぎない。
            画面内は最大8枚、9枚目以降は「さらに見る」へ。
          </p>
          <div className="gesture-note">
            <span>↕</span>
            <p><b>全件表示は縦スクロール</b><br/>横スワイプで閉じる観劇情報ページと干渉させません。</p>
          </div>
        </div>
        <div className="gallery-demo">
          {Array.from({ length: 8 }, (_, index) => (
            <div className={`gallery-tile tile-${index + 1}`} key={index}>
              {index === 7 && <span>＋12<br/><small>さらに見る</small></span>}
            </div>
          ))}
        </div>
      </section>

      <footer>
        <span>Favoreco</span>
        <p>公演を見つけた瞬間も、思い出す夜も、同じ記録のつづき。</p>
        <small>Unified theater form — implementation concept</small>
      </footer>
    </main>
  );
}
