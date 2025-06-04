// economicsTokenomics/governance.service.ts
import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import {
  GovernanceProposal,
  ProposalStatus,
} from "./entities/governance-proposal.entity";
import { Vote } from "./entities/vote.entity";
import { StakingPosition } from "./entities/staking-position.entity";
import { CreateProposalDto, VoteDto } from "./dto/governance.dto";
import { ethers } from "ethers";

@Injectable()
export class GovernanceService {
  constructor(
    @InjectRepository(GovernanceProposal)
    private proposalRepository: Repository<GovernanceProposal>,
    @InjectRepository(Vote)
    private voteRepository: Repository<Vote>,
    @InjectRepository(StakingPosition)
    private stakingPositionRepository: Repository<StakingPosition>
  ) {}

  async createProposal(createProposalDto: CreateProposalDto) {
    const { title, description, votingEnd, executionData } = createProposalDto;

    const proposer = "user-address"; // In real implementation, get from authenticated user
    const votingPower = await this.getVotingPower(proposer);

    // Require minimum voting power to create proposal
    const minProposalPower = ethers.utils.parseEther("1000"); // 1000 CGIFT
    if (ethers.utils.parseEther(votingPower.votingPower).lt(minProposalPower)) {
      throw new BadRequestException(
        "Insufficient voting power to create proposal"
      );
    }

    const votingStart = new Date();
    const proposal = this.proposalRepository.create({
      title,
      description,
      proposer,
      votesFor: "0",
      votesAgainst: "0",
      quorumRequired: ethers.utils.formatEther(
        ethers.utils.parseEther("10000")
      ), // 10k CGIFT quorum
      status: ProposalStatus.ACTIVE,
      votingStart,
      votingEnd: new Date(votingEnd),
      executionData,
    });

    await this.proposalRepository.save(proposal);

    return {
      success: true,
      proposalId: proposal.id,
      proposal,
    };
  }

  async getProposals(status?: string, page: number = 1, limit: number = 10) {
    const query = this.proposalRepository
      .createQueryBuilder("proposal")
      .leftJoinAndSelect("proposal.votes", "votes")
      .orderBy("proposal.createdAt", "DESC")
      .skip((page - 1) * limit)
      .take(limit);

    if (status) {
      query.where("proposal.status = :status", { status });
    }

    const [proposals, total] = await query.getManyAndCount();

    return {
      proposals,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getProposal(id: string) {
    const proposal = await this.proposalRepository.findOne({
      where: { id },
      relations: ["votes"],
    });

    if (!proposal) {
      throw new NotFoundException("Proposal not found");
    }

    return { proposal };
  }

  async vote(voteDto: VoteDto) {
    const { proposalId, support, reason } = voteDto;
    const voter = "user-address"; // In real implementation, get from authenticated user

    const proposal = await this.proposalRepository.findOne({
      where: { id: proposalId },
    });
    if (!proposal) {
      throw new NotFoundException("Proposal not found");
    }

    if (proposal.status !== ProposalStatus.ACTIVE) {
      throw new BadRequestException("Proposal is not active for voting");
    }

    if (new Date() > proposal.votingEnd) {
      throw new BadRequestException("Voting period has ended");
    }

    // Check if user already voted
    const existingVote = await this.voteRepository.findOne({
      where: { voter, proposal: { id: proposalId } },
    });

    if (existingVote) {
      throw new BadRequestException("User has already voted on this proposal");
    }

    const votingPower = await this.getVotingPower(voter);
    const vote = this.voteRepository.create({
      voter,
      votingPower: votingPower.votingPower,
      support: support === "true",
      reason,
      proposal,
    });

    await this.voteRepository.save(vote);

    // Update proposal vote counts
    const votePower = ethers.utils.parseEther(votingPower.votingPower);
    const currentVotesFor = ethers.utils.parseEther(proposal.votesFor);
    const currentVotesAgainst = ethers.utils.parseEther(proposal.votesAgainst);

    if (support === "true") {
      await this.proposalRepository.update(proposalId, {
        votesFor: ethers.utils.formatEther(currentVotesFor.add(votePower)),
      });
    } else {
      await this.proposalRepository.update(proposalId, {
        votesAgainst: ethers.utils.formatEther(
          currentVotesAgainst.add(votePower)
        ),
      });
    }

    return {
      success: true,
      voteId: vote.id,
      votingPower: votingPower.votingPower,
    };
  }

  async getVotingPower(userAddress: string) {
    const stakingPositions = await this.stakingPositionRepository.find({
      where: { userAddress, isActive: true },
    });

    let totalVotingPower = ethers.BigNumber.from(0);

    for (const position of stakingPositions) {
      const stakedAmount = ethers.utils.parseEther(position.stakedAmount);

      // Apply multiplier based on lock period
      let multiplier = 100; // 1x for no lock
      if (position.lockPeriod >= 90) {
        multiplier = 200; // 2x for 90+ days
      } else if (position.lockPeriod >= 30) {
        multiplier = 150; // 1.5x for 30+ days
      }

      const votingPower = stakedAmount.mul(multiplier).div(100);
      totalVotingPower = totalVotingPower.add(votingPower);
    }

    return {
      votingPower: ethers.utils.formatEther(totalVotingPower),
      stakingPositions: stakingPositions.length,
    };
  }

  async executeProposal(proposalId: string) {
    const proposal = await this.proposalRepository.findOne({
      where: { id: proposalId },
    });
    if (!proposal) {
      throw new NotFoundException("Proposal not found");
    }

    if (proposal.status !== ProposalStatus.SUCCEEDED) {
      throw new BadRequestException("Proposal has not succeeded");
    }

    // Execute proposal logic here
    await this.proposalRepository.update(proposalId, {
      status: ProposalStatus.EXECUTED,
    });

    return {
      success: true,
      proposalId,
      executedAt: new Date(),
    };
  }
}
