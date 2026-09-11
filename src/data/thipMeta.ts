import type { GroupMeta, IndicatorGroup } from '@/types/thip';

export const sourceDictionaryCount = 232;

export const groupMeta: Record<IndicatorGroup, GroupMeta> = {
  D: {
    key: 'D',
    label: 'Disease',
    shortLabel: 'รายโรค',
    description: 'ผลลัพธ์จำแนกตามกลุ่มโรคสำคัญ',
    color: '#2dc9c5',
  },
  C: {
    key: 'C',
    label: 'Care process',
    shortLabel: 'กระบวนการดูแล',
    description: 'คุณภาพกระบวนการดูแลผู้ป่วย',
    color: '#f4b942',
  },
  S: {
    key: 'S',
    label: 'System',
    shortLabel: 'ระบบงาน',
    description: 'ตัวชี้วัดระบบสนับสนุนสำคัญ',
    color: '#8c7cff',
  },
  H: {
    key: 'H',
    label: 'Health promotion',
    shortLabel: 'สร้างเสริมสุขภาพ',
    description: 'การสร้างเสริมสุขภาพบุคลากรและผู้รับบริการ',
    color: '#ef7b68',
  },
  A: {
    key: 'A',
    label: 'Ambulatory care',
    shortLabel: 'ผู้ป่วยนอก',
    description: 'โรคที่ควรดูแลด้วยบริการผู้ป่วยนอก',
    color: '#5d9cec',
  },
};
