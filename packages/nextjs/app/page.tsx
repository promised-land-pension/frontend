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
import { simulateContract, writeContract, getAccount } from "@wagmi/core";
import type { NextPage } from "next";
import { Abi, http, parseEther, custom } from "viem";
import {
  createConfig,
  useAccount,
  useBalance,
  useConnect,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useWriteContract,
} from "wagmi";
import { injected } from '@wagmi/connectors'

import { avalancheFuji, mainnet, scrollSepolia } from "wagmi/chains";
import { BugAntIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { addresses } from "~~/assets/addresses";
import { Address } from "~~/components/scaffold-eth";
import FlowingBalance from "~~/components/FlowingBalance";

// **Contract Addresses**
const PENSIONS_CONTRACT_ADDRESS = "0xAaa603469595050Eb3Be4c4735DB50ef7cEEfd6d";
const CFAv1ForwarderAddress = "0x2CDd45c5182602a36d391F7F16DD9f8386C3bD8D";

// **Token Addresses & ABIs**
const CASH_TOKEN_ADDRESS = "0xfFD0f6d73ee52c68BF1b01C8AfA2529C97ca17F3";
const TIME_TOKEN_ADDRESS = "0x12345678901234567890123456789012";

/*const config = createConfig({
  chains: [scrollSepolia],
  connectors: [injected()], 
  transports: {
    //[mainnet.id]: http(),
    //[avalancheFuji.id]: http(),
    //[scrollSepolia.id]: custom(window.ethereum!),
    [scrollSepolia.id]: http(),
  },
});*/

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
        <div className={isConnected ? "container left" : "container center"}
          style={{lineHeight: "2", fontSize: "1.5rem", fontFamily: "sans-serif"}}
        >
          <h1>Welcome to your new life</h1>
          <h1>Game rules</h1>
          <ul>
            <li>Default Retirement Age increases every time someone retires.</li>
            <li>People that get to the age compete for the slot.</li>
            <li>The slot goes to the one that got the most money in out of the applicants.</li>
            <li>The ones that don’t get the slot have to start over.</li>
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

  const { data: userTimeBalance } = useReadContract({
    address: addresses.scrollSepoliaReceiverContract,
    abi: PensionsAbi,
    functionName: "timeBalance",
    args: [address as `0x${string}`],
  });

  const { data: retirementAge } = useReadContract({
    address: addresses.scrollSepoliaReceiverContract,
    abi: PensionsAbi,
    functionName: "retirementAge",
  });


  function formatTimeBalance(balance: bigint) {
    console.log("about to format balance", balance);
    return balance ? (Number(balance.toString()) / 1e18).toFixed(5) : "Loading...";
  }

  const { writeContract, status, error, data } = useWriteContract();

  // Claim Pension handler
  const handleClaimPension = async () => {
    await writeContract({
      abi: CFAv1ForwarderAbi,
      address: addresses.CFAv1ForwarderScrollSepolia as `0x${string}`,
      functionName: "deleteFlow",
      args: [
        addresses.cashSepoliaScroll as `0x${string}`, // Your super token address\
        address as `0x${string}`,
        addresses.scrollSepoliaReceiverContract as `0x${string}`,
        "0x",
      ],
      chainId: scrollSepolia.id,
    });

  }

  return (
    isConnected && (
      <Card mt="6">
        <CardBody>
          <Stack spacing="3">
            <Heading size="md">Player Status</Heading>
            {userTimeBalance ? <Text>Worked so far: {(Number(userTimeBalance)/1e18 /60/60).toFixed(2)} YEARS</Text> : <Text>Balance (TIME): Loading...</Text>}
            {retirementAge ? <Text>Retirement Age: {Number(retirementAge.toString())/60/60} YEARS</Text> : <Text>Retirement Age: Loading...</Text>}
            <Divider />
            {/* Conditionally render the claim button */}
            {userTimeBalance ? (
              retirementAge && Number(userTimeBalance) >= Number(retirementAge) * 1e18 ? (
                <Button onClick={handleClaimPension} style={{width: "10em"}}>Retire</Button>
              ) : (
                <>
                <Text>You will be eligible for a pension very soon.</Text>
                {retirementAge && <Text>Just keep working for {Number((Number(retirementAge.toString()) - Number(userTimeBalance.toString())/1e18) / 60 / 60).toFixed(2)} more years. </Text>}
                </>
              )
            ) : (
              <Text>Loading...</Text>
            )}
          </Stack>
        </CardBody>
      </Card>
    )
  );
}

function Actions() {
  const { address, isConnected } = useAccount();
  //const { connect, connectors } = useConnect();
  //const { connector } = getAccount(config)

  const toast = useToast();

  // Superfluid Stream State
  const [open, setOpen] = useState(false);
  const [monthlyFlowRate, setMonthlyFlowRate] = useState("");
  const [flowRate, setFlowRate] = useState<string>("");
  const [startTime, setStartTime] = useState<Date>(new Date());

  // Handle Monthly Flow Rate Change
  const onMonthlyFlowRateChange = (e: ChangeEvent<HTMLInputElement>) => {
    setMonthlyFlowRate(e.target.value);
  };

  useEffect(() => {
    if (monthlyFlowRate) {
      const monthlyFlowrateValue = Number(monthlyFlowRate);
      if (!isNaN(monthlyFlowrateValue)) {
        const normalizedFlowRate = ((monthlyFlowrateValue * 1e18) / (365/12 * 60 * 60 * 24)).toFixed(0);
        setFlowRate(normalizedFlowRate);
      }
    }
  }, [monthlyFlowRate]);

  const openDialog = () => {
    setOpen(true);
  };
  const closeDialog = () => {
    setOpen(false);
  };

  const { data: streamData } = useReadContract({
    abi: CFAv1ForwarderAbi,
    address: addresses.CFAv1ForwarderScrollSepolia as `0x${string}`,
    functionName: "getFlowrate",
    args: [
      addresses.cashSepoliaScroll as `0x${string}`,
      address as `0x${string}`,
      addresses.scrollSepoliaReceiverContract as `0x${string}`,
    ],
  });
  console.log(streamData);

  const handleCreateStream = async () => {
      await writeContract({
      abi: CFAv1ForwarderAbi,
      address: addresses.CFAv1ForwarderScrollSepolia as `0x${string}`,
      functionName: "createFlow",
      args: [
        addresses.cashSepoliaScroll as `0x${string}`, // Your super token address\
        address as `0x${string}`,
        addresses.scrollSepoliaReceiverContract as `0x${string}`,
        BigInt(flowRate),
        "0x",
      ],
      chainId: scrollSepolia.id,
    });

  };

  const { writeContract, status, error, data } = useWriteContract();

  useEffect(() => {
    console.log("Transaction successful!");
      toast({
        title: "Transaction confirmed",
        description: <>Transaction hash: ${data} - see on <a href="https://eth.blockscout.com/tx/0xc84df957440156bd918769bd9809323b552041258f389f5b54c6f61c735a03c3">blockscout</a> </>,
        status: "info",
        duration: 5000,
        isClosable: true,
      });
      closeDialog();
      setStartTime(new Date());
  }, [data]);

  const handleUpdateStream = async () => {
    await writeContract({
      abi: CFAv1ForwarderAbi,
      address: addresses.CFAv1ForwarderScrollSepolia as `0x${string}`,
      functionName: "updateFlow",
      args: [
        addresses.cashSepoliaScroll as `0x${string}`, // Your super token address\
        address as `0x${string}`,
        addresses.scrollSepoliaReceiverContract as `0x${string}`,
        BigInt(flowRate),
        "0x",
      ],
      chainId: scrollSepolia.id
    });
  };

  return isConnected ? (
    <Card mt="6">
      <CardBody>
        <Stack spacing="3">
          <Heading size="md">Actions</Heading>
          {
            // if stream exists, show stream + update button
            streamData 
            ? (
              <>
                <Text>Streaming {(Number((streamData* BigInt(365/12 * 24 * 3600)).toString())/1e18).toFixed(5)} APE/month</Text>
                <Text>
                  <FlowingBalance
                    startingBalance={BigInt(0)}
                    startingBalanceDate={startTime}
                    flowRate={streamData as bigint}
                  /> Streamed so far.
                </Text>
                <Button
                  onClick={openDialog}
                >Update Stream</Button>
              </>
            ) : (
              // if stream doesn't exist, show create stream button
              // Stream Button and Modal
              <Button data-cy={"open-dialog"} onClick={openDialog}>
                Start Stream
              </Button>
            )
          }
        </Stack>
      </CardBody>
      <Modal isOpen={open} onClose={closeDialog}>
        <ModalContent>
          <ModalHeader>Your way to freedom</ModalHeader>
          <ModalBody>
            To start working honestly, we kindly ask you to give us your money by creating a stream. Select the amount
            of APE you want to stream monthly.
            { streamData ? (
              <>
              <Text>Currently Streaming {(Number((streamData* BigInt(365/12 * 24 * 3600)).toString())/1e18).toFixed(5)} APE/month</Text>
              <Input onChange={onMonthlyFlowRateChange} value={monthlyFlowRate} placeholder="APE/month"/>
              </>
            ) : (
              <Input onChange={onMonthlyFlowRateChange} value={monthlyFlowRate} placeholder="APE/month"/>
            )}
          </ModalBody>
          <ModalFooter>
            <Button onClick={closeDialog} style={{marginRight: "10px"}}>Cancel</Button>
            {
              !streamData ? (
                <Button
                  type="submit"
                  onClick={handleCreateStream}
                >
                  Create stream
                </Button>
              ) : (
                <Button
                  type="submit"
                  onClick={handleUpdateStream}
                >
                  Update stream
                </Button>
              )
            }
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
