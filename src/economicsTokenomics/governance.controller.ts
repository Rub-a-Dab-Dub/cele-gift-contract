// economicsTokenomics/governance.controller.ts
import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
} from "@nestjs/common";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from "@nestjs/swagger";
import { GovernanceService } from "./governance.service";
import { CreateProposalDto, VoteDto } from "./dto/governance.dto";

@ApiTags("Governance")
@Controller("governance")
export class GovernanceController {
  constructor(private readonly governanceService: GovernanceService) {}

  @Post("proposals")
  @ApiOperation({ summary: "Create a governance proposal" })
  @ApiBearerAuth()
  async createProposal(@Body() createProposalDto: CreateProposalDto) {
    return this.governanceService.createProposal(createProposalDto);
  }

  @Get("proposals")
  @ApiOperation({ summary: "Get all governance proposals" })
  async getProposals(
    @Query("status") status?: string,
    @Query("page") page: number = 1,
    @Query("limit") limit: number = 10
  ) {
    return this.governanceService.getProposals(status, page, limit);
  }

  @Get("proposals/:id")
  @ApiOperation({ summary: "Get proposal by ID" })
  async getProposal(@Param("id") id: string) {
    return this.governanceService.getProposal(id);
  }

  @Post("vote")
  @ApiOperation({ summary: "Cast a vote on a proposal" })
  @ApiBearerAuth()
  async vote(@Body() voteDto: VoteDto) {
    return this.governanceService.vote(voteDto);
  }

  @Get("voting-power/:userAddress")
  @ApiOperation({ summary: "Get user voting power" })
  async getVotingPower(@Param("userAddress") userAddress: string) {
    return this.governanceService.getVotingPower(userAddress);
  }

  @Post("execute/:proposalId")
  @ApiOperation({ summary: "Execute a successful proposal" })
  @ApiBearerAuth()
  async executeProposal(@Param("proposalId") proposalId: string) {
    return this.governanceService.executeProposal(proposalId);
  }
}
