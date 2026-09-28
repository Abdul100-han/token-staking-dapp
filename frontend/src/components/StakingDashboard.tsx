"use client";

import { useEffect, useMemo, useState } from "react";
import {
  useAccount,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";
import { formatEther, maxUint256, parseEther } from "viem";
import { Loader2 } from "lucide-react";
import {
  CONTRACT_ADDRESSES,
  ERC20_ABI,
  STAKING_ENGINE_ABI,
} from "../constants";

const FAUCET_AMOUNT = parseEther("100");

function formatToken(value?: bigint, digits = 6) {
  if (value === undefined) {
    return "—";
  }

  const formatted = formatEther(value);
  const asNumber = Number(formatted);
  if (!Number.isFinite(asNumber) || asNumber === 0) {
    return asNumber === 0 ? "0" : formatted;
  }
  if (asNumber > 0 && asNumber < 1 / 10 ** digits) {
    return formatted;
  }

  return asNumber.toFixed(Math.min(digits, 6)).replace(/\.?0+$/, "");
}

export function StakingDashboard() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState("");
  const [action, setAction] = useState<string | null>(null);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const { writeContract, data: hash, isPending, error, reset } =
    useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });
  const isBusy = isPending || isConfirming;

  const { data: walletBalance, refetch: refetchWalletBalance } = useReadContract({
    address: CONTRACT_ADDRESSES.STAKING_TOKEN,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address), refetchInterval: 4_000 },
  });

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CONTRACT_ADDRESSES.STAKING_TOKEN,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: address
      ? [address, CONTRACT_ADDRESSES.STAKING_ENGINE]
      : undefined,
    query: { enabled: Boolean(address), refetchInterval: 4_000 },
  });

  const { data: totalStaked, refetch: refetchTotalStaked } = useReadContract({
    address: CONTRACT_ADDRESSES.STAKING_ENGINE,
    abi: STAKING_ENGINE_ABI,
    functionName: "totalSupply",
    query: { refetchInterval: 4_000 },
  });

  const { data: userStaked, refetch: refetchUserStaked } = useReadContract({
    address: CONTRACT_ADDRESSES.STAKING_ENGINE,
    abi: STAKING_ENGINE_ABI,
    functionName: "balances",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address), refetchInterval: 4_000 },
  });

  const { data: pendingRewards, refetch: refetchRewards } = useReadContract({
    address: CONTRACT_ADDRESSES.STAKING_ENGINE,
    abi: STAKING_ENGINE_ABI,
    functionName: "earned",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address), refetchInterval: 1_000 },
  });

  useEffect(() => {
    if (!isSuccess) {
      return;
    }

    void Promise.all([
      refetchWalletBalance(),
      refetchAllowance(),
      refetchTotalStaked(),
      refetchUserStaked(),
      refetchRewards(),
    ]);
  }, [
    isSuccess,
    refetchAllowance,
    refetchRewards,
    refetchTotalStaked,
    refetchUserStaked,
    refetchWalletBalance,
  ]);

  const parsedAmount = useMemo(() => {
    try {
      if (!amount || Number(amount) <= 0) {
        return undefined;
      }
      return parseEther(amount);
    } catch {
      return undefined;
    }
  }, [amount]);

  const needsApproval =
    parsedAmount !== undefined &&
    (allowance === undefined || allowance < parsedAmount);

  function submit(
    nextAction: string,
    writeArgs: Parameters<typeof writeContract>[0],
  ) {
    reset();
    setAction(nextAction);
    writeContract(writeArgs);
  }

  function handleMint() {
    if (!address) {
      return;
    }
    submit("Minting 100 STK", {
      address: CONTRACT_ADDRESSES.STAKING_TOKEN,
      abi: ERC20_ABI,
      functionName: "mint",
      args: [address, FAUCET_AMOUNT],
    });
  }

  function handleApprove() {
    submit("Approving STK", {
      address: CONTRACT_ADDRESSES.STAKING_TOKEN,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [CONTRACT_ADDRESSES.STAKING_ENGINE, maxUint256],
    });
  }

  function handleStake() {
    if (!parsedAmount) {
      return;
    }
    submit("Staking STK", {
      address: CONTRACT_ADDRESSES.STAKING_ENGINE,
      abi: STAKING_ENGINE_ABI,
      functionName: "stake",
      args: [parsedAmount],
    });
  }

  function handleWithdraw() {
    if (!parsedAmount) {
      return;
    }
    submit("Withdrawing STK", {
      address: CONTRACT_ADDRESSES.STAKING_ENGINE,
      abi: STAKING_ENGINE_ABI,
      functionName: "withdraw",
      args: [parsedAmount],
    });
  }

  function handleClaim() {
    submit("Claiming rewards", {
      address: CONTRACT_ADDRESSES.STAKING_ENGINE,
      abi: STAKING_ENGINE_ABI,
      functionName: "claimReward",
    });
  }

  const metrics = [
    {
      label: "Total Staked",
      value: !mounted ? "…" : formatToken(totalStaked),
      suffix: "STK",
    },
    {
      label: "Your Stake",
      value: !mounted ? "…" : formatToken(userStaked),
      suffix: "STK",
    },
    {
      label: "Wallet Balance",
      value: !mounted ? "…" : formatToken(walletBalance),
      suffix: "STK",
    },
    {
      label: "Pending Rewards",
      value: !mounted ? "…" : formatToken(pendingRewards, 12),
      suffix: "RWD",
    },
  ];

  return (
    <section className="space-y-6">
      <div>
        <h1 className="text-3xl font-semibold tracking-tight text-white">
          Stake STK. Earn RWD.
        </h1>
        <p className="mt-2 max-w-2xl text-sm text-slate-400">
          Deposit Staking Token on Sepolia, accrue rewards every second, then
          claim Reward Token from the vault.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {metrics.map((metric) => (
          <div
            key={metric.label}
            className="rounded-2xl border border-slate-800 bg-slate-900 p-4"
          >
            <p className="text-xs uppercase tracking-wide text-slate-400">
              {metric.label}
            </p>
            <p className="mt-2 truncate text-2xl font-semibold text-white">
              {metric.value}
            </p>
            <p className="text-xs text-slate-500">{metric.suffix}</p>
          </div>
        ))}
      </div>

      <div className="rounded-2xl border border-slate-800 bg-slate-900 p-6">
        {!mounted || !isConnected ? (
          <p className="text-sm text-slate-300">
            Connect a Sepolia wallet to mint test tokens, stake, withdraw, and
            claim rewards.
          </p>
        ) : (
          <div className="space-y-5">
            <label className="block space-y-2">
              <span className="text-sm font-medium text-slate-200">Amount</span>
              <div className="flex gap-2">
                <input
                  type="number"
                  min="0"
                  step="any"
                  value={amount}
                  onChange={(event) => setAmount(event.target.value)}
                  placeholder="0.0"
                  className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-white outline-none ring-emerald-500/40 placeholder:text-slate-500 focus:ring-2"
                />
                <button
                  type="button"
                  onClick={() =>
                    setAmount(
                      walletBalance ? formatEther(walletBalance) : "0",
                    )
                  }
                  className="rounded-xl border border-slate-700 px-4 text-sm font-semibold text-emerald-400 hover:bg-slate-800"
                >
                  MAX
                </button>
              </div>
            </label>

            <div className="grid gap-3 sm:grid-cols-2">
              {needsApproval ? (
                <button
                  type="button"
                  disabled={isBusy || !parsedAmount}
                  onClick={handleApprove}
                  className="rounded-xl bg-amber-500 px-4 py-3 font-semibold text-slate-950 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Approve STK
                </button>
              ) : (
                <button
                  type="button"
                  disabled={isBusy || !parsedAmount}
                  onClick={handleStake}
                  className="rounded-xl bg-emerald-500 px-4 py-3 font-semibold text-slate-950 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Stake STK
                </button>
              )}

              <button
                type="button"
                disabled={isBusy || !parsedAmount}
                onClick={handleWithdraw}
                className="rounded-xl border border-slate-700 px-4 py-3 font-semibold text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Withdraw
              </button>

              <button
                type="button"
                disabled={isBusy}
                onClick={handleClaim}
                className="rounded-xl border border-slate-700 px-4 py-3 font-semibold text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Claim Rewards
              </button>

              <button
                type="button"
                disabled={isBusy}
                onClick={handleMint}
                className="rounded-xl bg-slate-100 px-4 py-3 font-semibold text-slate-950 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Mint Test Tokens
              </button>
            </div>

            {isBusy && (
              <p className="flex items-center gap-2 text-sm text-amber-300">
                <Loader2 className="h-4 w-4 animate-spin" />
                {action ?? "Confirm in your wallet"}
                {isConfirming ? " — waiting for Sepolia confirmation" : ""}
              </p>
            )}

            {isSuccess && !isBusy && (
              <p className="text-sm text-emerald-400">
                Transaction confirmed. Balances updated.
              </p>
            )}

            {error && (
              <p className="text-sm text-rose-400">
                {error.shortMessage ?? error.message}
              </p>
            )}
          </div>
        )}
      </div>
    </section>
  );
}
