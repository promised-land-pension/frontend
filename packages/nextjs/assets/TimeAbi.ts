export const TimeAbi = [
  { stateMutability: "payable", type: "fallback" },
  {
    inputs: [{ internalType: "address", name: "initialAddress", type: "address" }],
    name: "initializeProxy",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  { stateMutability: "payable", type: "receive" },
];
