// economicsTokenomics/dto/governance.dto.ts
import { IsString, IsDateString, IsOptional, IsEnum } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";
import { ProposalStatus } from "../entities/governance-proposal.entity";

export class CreateProposalDto {
  @ApiProperty({ description: "Proposal title" })
  @IsString()
  title: string;

  @ApiProperty({ description: "Proposal description" })
  @IsString()
  description: string;

  @ApiProperty({ description: "Voting end date" })
  @IsDateString()
  votingEnd: string;

  @ApiProperty({ description: "Execution data", required: false })
  @IsOptional()
  executionData?: any;
}

export class VoteDto {
  @ApiProperty({ description: "Proposal ID" })
  @IsString()
  proposalId: string;

  @ApiProperty({ description: "Support (true for yes, false for no)" })
  @IsString()
  support: string;

  @ApiProperty({ description: "Voting reason", required: false })
  @IsOptional()
  @IsString()
  reason?: string;
}
