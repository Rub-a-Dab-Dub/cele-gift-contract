// economicsTokenomics/entities/governance-proposal.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from "typeorm";
import { Vote } from "./vote.entity";

export enum ProposalStatus {
  PENDING = "pending",
  ACTIVE = "active",
  SUCCEEDED = "succeeded",
  DEFEATED = "defeated",
  EXECUTED = "executed",
  CANCELLED = "cancelled",
}

@Entity("governance_proposals")
export class GovernanceProposal {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column()
  title: string;

  @Column("text")
  description: string;

  @Column()
  proposer: string;

  @Column("decimal", { precision: 36, scale: 18 })
  votesFor: string;

  @Column("decimal", { precision: 36, scale: 18 })
  votesAgainst: string;

  @Column("decimal", { precision: 36, scale: 18 })
  quorumRequired: string;

  @Column({
    type: "enum",
    enum: ProposalStatus,
    default: ProposalStatus.PENDING,
  })
  status: ProposalStatus;

  @Column()
  votingStart: Date;

  @Column()
  votingEnd: Date;

  @Column("json", { nullable: true })
  executionData: any;

  @OneToMany(() => Vote, (vote) => vote.proposal)
  votes: Vote[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}