// economicsTokenomics/entities/vote.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
} from "typeorm";
import { GovernanceProposal } from "./governance-proposal.entity";

@Entity("votes")
export class Vote {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column()
  voter: string;

  @Column("decimal", { precision: 36, scale: 18 })
  votingPower: string;

  @Column()
  support: boolean; // true for yes, false for no

  @Column("text", { nullable: true })
  reason: string;

  @ManyToOne(() => GovernanceProposal, (proposal) => proposal.votes)
  proposal: GovernanceProposal;

  @CreateDateColumn()
  createdAt: Date;
}
