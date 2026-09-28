import { Header } from "../components/Header";
import { StakingDashboard } from "../components/StakingDashboard";

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col bg-slate-950 text-slate-100">
      <Header />
      <main className="container mx-auto max-w-5xl flex-1 px-4 py-8">
        <StakingDashboard />
      </main>
      <footer className="border-t border-slate-800 py-6 text-center text-sm text-slate-500">
        Built for Sepolia ·{" "}
        <a
          href="https://github.com/Abdul100-han/token-staking-dapp"
          target="_blank"
          rel="noopener noreferrer"
          className="text-emerald-400 hover:underline"
        >
          View on GitHub
        </a>
      </footer>
    </div>
  );
}
