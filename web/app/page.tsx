import { Dashboard } from "@/components/Dashboard";

export default function Home() {
  return (
    <main>
      <section className="mx-auto max-w-3xl px-4 pt-10 text-center">
        <p className="mb-2 text-xs uppercase tracking-[0.2em] text-frost-glow">
          CLAY Hackathon · Lofi × Sui
        </p>
        <h1 className="text-3xl font-extrabold sm:text-4xl">
          Freeze your <span className="text-frost-ice">BTC</span>. Borrow on Sui.
        </h1>
        <p className="mx-auto mt-3 max-w-xl text-sm text-slate-400">
          Deposit wrapped BTC as collateral and borrow a USD stablecoin against
          it. Your loan is a Move object you own. If BTC drops, anyone can
          liquidate underwater positions — with the sale routed through Deepbook.
        </p>
      </section>
      <Dashboard />
    </main>
  );
}
