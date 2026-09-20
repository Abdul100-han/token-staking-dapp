import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: "Token Staking DApp",
  projectId:
    process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ||
    "YOUR_WALLETCONNECT_PROJECT_ID",
  chains: [sepolia],
  ssr: true,
});
