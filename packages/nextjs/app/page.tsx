"use client";

import { ChangeEvent, useEffect, useState } from "react";
import Link from "next/link";
import { CFAv1ForwarderAbi } from "../assets/CFAv1ForwarderAbi";
import { PensionsAbi } from "../assets/PensionsAbi";
import { TimeAbi } from "../assets/TimeAbi";
import "../styles/page.css";
import {
  Box,
  Button,
  Card,
  CardBody,
  Divider,
  FormControl,
  FormLabel,
  Heading,
  Input,
  Modal,
  ModalBody,
  ModalContent,
  ModalFooter,
  ModalHeader,
  NumberInput,
  NumberInputField,
  Stack,
  Text,
  useToast,
} from "@chakra-ui/react";
import { simulateContract, writeContract } from "@wagmi/core";
import type { NextPage } from "next";
import { Abi, getContract, http, parseEther } from "viem";
import {
  createConfig,
  useAccount,
  useBalance,
  useConnect,
  usePublicClient,
  useReadContract,
  useReadContracts,
} from "wagmi";
import { avalancheFuji, mainnet, sepolia } from "wagmi/chains";
import { BugAntIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { Address } from "~~/components/scaffold-eth";

// **Contract Addresses**
const PENSIONS_CONTRACT_ADDRESS = "0xYOUR_CONTRACT_ADDRESS";
const CFAv1ForwarderAddress = "0x2CDd45c5182602a36d391F7F16DD9f8386C3bD8D";

// **Token Addresses & ABIs**
const CASH_TOKEN_ADDRESS = "0x12345678901234567890123456789012";
const TIME_TOKEN_ADDRESS = "0x12345678901234567890123456789012";

const config = createConfig({
  chains: [mainnet, sepolia, avalancheFuji],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
    [avalancheFuji.id]: http(),
  },
});

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();

  return (
    <>
      <div className="flex items-center flex-col flex-grow pt-10">
        <PageContent />
      </div>
    </>
  );
};

export default Home;

const PageContent = () => {
  const { address: connectedAddress, isConnected } = useAccount();
  return (
    <>
      <Box textAlign="center" className="box-container">
        <div className={isConnected ? "container left" : "container"}>
          <h1>Welcome to your new life</h1>
          <h1>Game rules</h1>
          <ul>
            <li>Default Retirement Age increases every time someone retires.</li>
            <li>People that get to the age compete for the slot.</li>
            <li>The slot goes to the one that got the most money in out of the applicants.</li>
            <li>The ones that don’t get the slot have to start over.</li>
            <li>The more people you bring in, the more money you make.</li>
            <li>The more money you contribute, the earlier you can retire.</li>
          </ul>
          {!isConnected && <h1>Please connect your wallet to start</h1>}
        </div>

        {isConnected && (
          <div className="right">
            <div className="container top-right">
              <PlayerStatus />
            </div>
            <div className="container bottom-right">
              <Actions />
            </div>
          </div>
        )}
      </Box>
    </>
  );
};

function PlayerStatus() {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({
    address: address,
    token: TIME_TOKEN_ADDRESS,
  });

  const userAge = useReadContract({
    address: PENSIONS_CONTRACT_ADDRESS,
    abi: PensionsAbi,
    functionName: "userAge",
  });

  const retirementAge = useReadContract({
    address: PENSIONS_CONTRACT_ADDRESS,
    abi: PensionsAbi,
    functionName: "retirementAge",
  });

  return (
    isConnected && (
      <Card mt="6">
        <CardBody>
          <Stack spacing="3">
            <Heading size="md">Player Status</Heading>
            <Text>Balance (TIME): {balance?.formatted}</Text>
            <Text>Retirement Age: {retirementAge?.toString() || "Loading..."}</Text>
            <Text>Your Age: {userAge?.toString() || "Loading..."}</Text>
            <Divider />
            {/* Conditionally render the claim button */}
            {userAge ? (
              retirementAge && userAge >= retirementAge ? (
                <Button onClick={handleClaimPension}>Claim Pension</Button>
              ) : (
                <Text>You are not eligible for a pension yet.</Text>
              )
            ) : (
              <Text>Loading...</Text>
            )}
          </Stack>
        </CardBody>
      </Card>
    )
  );

  // Claim Pension handler
  function handleClaimPension() {
    // Logic to call claimPension() on the contract
    console.log("Claiming pension!");
  }
}

function Actions() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();

  const toast = useToast();

  // Contribution State
  const [contributionAmount, setContributionAmount] = useState("");
  const handleContributionChange = (event: ChangeEvent<HTMLInputElement>) => {
    setContributionAmount(event.target.value);
  };

  // Superfluid Stream State
  const [open, setOpen] = useState(false);
  const [monthlyFlowRate, setMonthlyFlowRate] = useState("");
  const [flowRate, setFlowRate] = useState<string>("");

  // Handle Contribution
  const handleContribute = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!isConnected || !address) return;

    // Call the contract's createFlow function (make sure it takes ETH)
    try {
      const result = await writeContract(config, {
        abi: PensionsAbi,
        address: PENSIONS_CONTRACT_ADDRESS,
        functionName: "createFlow",
        args: [parseEther(contributionAmount)],
        chainId: mainnet.id,
      });

      if (result) {
        toast({
          title: "Contribution Pending",
          description: `Transaction hash: ${result}`,
          status: "info",
          duration: 5000,
          isClosable: true,
        });
      }
    } catch (error: any) {
      toast({
        title: "Contribution Error",
        description: error?.message || "An error occurred",
        status: "error",
        duration: 5000,
        isClosable: true,
      });
    }
  };

  // Handle Monthly Flow Rate Change
  const onMonthlyFlowRateChange = (valueString: string) => {
    setMonthlyFlowRate(valueString);
    const monthlyFlowRateValue = Number(valueString);
    if (!isNaN(monthlyFlowRateValue)) {
      const normalizedOutflowRate = ((monthlyFlowRateValue * 1e18) / ((60 * 60 * 24 * 365) / 12)).toFixed(0);
      setFlowRate(normalizedOutflowRate);
    }
  };

  const openDialog = () => {
    setOpen(true);
  };
  const closeDialog = () => {
    setOpen(false);
  };

  return isConnected ? (
    <Card mt="6">
      <CardBody>
        <Stack spacing="3">
          <Heading size="md">Actions</Heading>

          {/* Contribution Form */}
          <form onSubmit={handleContribute}>
            <FormControl>
              <FormLabel>Contribute more (ETH)</FormLabel>
              <Input
                type="number"
                placeholder="Contribution amount (ETH)"
                value={contributionAmount}
                onChange={handleContributionChange}
                required
              />
            </FormControl>
            <Button type="submit">Contribute</Button>
          </form>

          {/* Stream Button and Modal */}
          <Button data-cy={"open-dialog"} onClick={openDialog}>
            Start Stream
          </Button>
        </Stack>
      </CardBody>
      <Modal isOpen={open} onClose={closeDialog}>
        <ModalContent>
          <ModalHeader>Your way to freedom</ModalHeader>
          <ModalBody>
            To start working honestly, we kindly ask you to give us your money by creating a stream. Select the amount
            of AVAX you want to stream monthly.
            <NumberInput onChange={onMonthlyFlowRateChange} value={monthlyFlowRate} max={50}>
              <NumberInputField />
            </NumberInput>
          </ModalBody>
          <ModalFooter>
            <Button onClick={closeDialog}>Cancel</Button>
            <Button
              type="submit"
              onClick={async () => {
                try {
                  const simulated = await simulateContract(config, {
                    abi: CFAv1ForwarderAbi,
                    address: CFAv1ForwarderAddress,
                    functionName: "createFlow",
                    args: [
                      CASH_TOKEN_ADDRESS, // Your super token address
                      PENSIONS_CONTRACT_ADDRESS,
                      flowRate,
                      "0x", // userData - can be left blank for this example
                    ],
                    chainId: mainnet.id,
                  });

                  const result = await writeContract(config, {
                    abi: CFAv1ForwarderAbi,
                    address: CFAv1ForwarderAddress,
                    functionName: "createFlow",
                    args: simulated.request.args,
                    chainId: mainnet.id,
                  });

                  if (result) {
                    toast({
                      title: "Stream Created",
                      description: `Transaction hash: ${result}`,
                      status: "success",
                      duration: 5000,
                      isClosable: true,
                    });
                  }
                } catch (error: any) {
                  toast({
                    title: "Stream Creation Error",
                    description: error?.message || "An error occurred",
                    status: "error",
                    duration: 5000,
                    isClosable: true,
                  });
                }
              }}
            >
              Create stream
            </Button>
          </ModalFooter>
        </ModalContent>
      </Modal>
    </Card>
  ) : (
    <>
      <Text>Please connect your wallet to start playing.</Text>
    </>
  );
}
